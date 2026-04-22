#!/bin/bash

################################################################################
# Shared Catalog Release Library
# Generic functions for downloading assets, updating catalogs, and releasing
# Uses Python for JSON operations (no jq dependency)
################################################################################

set -e

################################################################################
# Dry-Run Configuration
################################################################################

CATALOG_DRY_RUN="${CATALOG_DRY_RUN:-0}"

function _dry_run_msg() {
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] $@"
    fi
}

function _run_cmd() {
    local cmd="$1"
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Would execute: $cmd"
        return 0
    else
        eval "$cmd"
    fi
}

function _skip_in_dry_run() {
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Skipping: $1"
        return 0
    fi
    return 1
}

################################################################################
# JSON Helper (using Python)
################################################################################

function _json_get() {
    local file="$1"
    local path="$2"
    python3 -c "import json; data=json.load(open('$file')); exec('result=data' + ''.join(f\"['{p}']\" if not p.startswith('[') else f\"[{p}]\" for p in '$path'.split('.'))); print(json.dumps(result) if not isinstance(result, str) else result)"
}

function _json_get_array() {
    local file="$1"
    local path="$2"
    python3 -c "import json; data=json.load(open('$file')); exec('result=data' + ''.join(f\"['{p}']\" if not p.startswith('[') else f\"[{p}]\" for p in '$path'.split('.'))); [print(item) for item in result]"
}

################################################################################
# Environment & Validation
################################################################################

function catalog_check_environment() {
    local required_vars=("artifactory_key")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "ERROR: Required environment variable '$var' is not set"
            return 1
        fi
    done
    
    echo "✓ Environment check passed"
    return 0
}

function catalog_validate_manifest() {
    local manifest_file="$1"
    
    if [ ! -f "$manifest_file" ]; then
        echo "ERROR: Manifest file not found: $manifest_file"
        return 1
    fi
    
    # Validate JSON syntax
    if ! python3 -m json.tool < "$manifest_file" > /dev/null 2>&1; then
        echo "ERROR: Manifest is not valid JSON"
        return 1
    fi
    
    # Check for required manifest keys
    local required_keys=("app_name" "package" "catalog" "release" "artifacts" "platforms")
    for key in "${required_keys[@]}"; do
        if ! python3 -c "import json; data=json.load(open('$manifest_file')); data['$key']" 2>/dev/null; then
            echo "ERROR: Manifest missing required key: $key"
            return 1
        fi
    done
    
    echo "✓ Manifest validation passed"
    return 0
}

################################################################################
# Asset Download
################################################################################

function catalog_download_assets() {
    local manifest_file="$1"
    local version="$2"
    
    if [ -z "$manifest_file" ] || [ -z "$version" ]; then
        echo "Usage: catalog_download_assets <manifest_file> <version>"
        return 1
    fi
    
    catalog_check_environment || return 1
    
    # Parse manifest using Python
    local manifest_data=$(python3 << PYEOF
import json
with open('$manifest_file') as f:
    data = json.load(f)
print(json.dumps({
    'repo_root': data['catalog']['repo_root'],
    'package': data['package'],
    'asset_path': data['catalog']['asset_path_template'],
    'base_url': data['artifacts']['base_url'],
    'files': [f['name'] for f in data['artifacts']['files']]
}))
PYEOF
)
    
    local repo_root=$(echo "$manifest_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['repo_root'])")
    local package=$(echo "$manifest_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['package'])")
    local asset_path=$(echo "$manifest_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['asset_path'])")
    local base_url=$(echo "$manifest_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['base_url'])")
    local token="$artifactory_key"
    
    # Construct target directory
    local target_dir="${repo_root}/${asset_path//\{PACKAGE\}/$package}"
    target_dir="${target_dir//\{VERSION\}/$version}"
    
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Would download assets to: $target_dir"
    else
        mkdir -p "$target_dir"
    fi
    
    echo "Downloading assets to: $target_dir"
    
    # Download each artifact file
    echo "$manifest_data" | python3 -c "import sys, json; files = json.load(sys.stdin)['files']; [print(f) for f in files]" | while read -r file_template; do
        local filename="${file_template//x.x.x/$version}"
        local url="${base_url//x.x.x/$version}${filename}"
        local tempfile="${target_dir}/${filename}.temp"
        local target_file="${target_dir}/${filename}"
        
        echo "  Downloading: $filename"
        
        if [ "$CATALOG_DRY_RUN" = "1" ]; then
            _dry_run_msg "Would download: $url → $target_file"
        else
            response=$(curl -H "X-JFrog-Art-Api: $token" -s -w "%{http_code}" -o "$tempfile" "$url" 2>&1)
            
            if [ "$response" = "200" ]; then
                mv "$tempfile" "$target_file"
                echo "    ✓ $url"
            else
                echo "    ✗ Failed (HTTP $response): $url"
                rm -f "$tempfile"
                return 1
            fi
        fi
    done
    
    echo "✓ Assets downloaded successfully"
    return 0
}

################################################################################
# Catalog Update
################################################################################

function catalog_update_json() {
    local manifest_file="$1"
    local version="$2"
    local update_date="$3"
    
    if [ -z "$manifest_file" ] || [ -z "$version" ] || [ -z "$update_date" ]; then
        echo "Usage: catalog_update_json <manifest_file> <version> <update_date>"
        return 1
    fi
    
    local repo_root=$(python3 -c "import json; print(json.load(open('$manifest_file'))['catalog']['repo_root'])")
    local index_file="${repo_root}/$(python3 -c "import json; print(json.load(open('$manifest_file'))['catalog']['index_file'])")"
    local package=$(python3 -c "import json; print(json.load(open('$manifest_file'))['package'])")
    
    if [ ! -f "$index_file" ]; then
        echo "ERROR: Catalog file not found: $index_file"
        return 1
    fi
    
    echo "Updating catalog: $index_file"
    
    # Create a temporary backup
    local backup_file="${index_file}.backup"
    
    if ! _skip_in_dry_run "Creating backup"; then
        cp "$index_file" "$backup_file"
    fi
    
    # Read platforms from manifest
    local platforms=$(python3 -c "import json; data=json.load(open('$manifest_file')); [print(p) for p in data['platforms']]")
    
    # Update using Python script
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Would update catalog with:"
        _dry_run_msg "  Version: $version"
        _dry_run_msg "  Date: $update_date"
        _dry_run_msg "  Platforms:"
        echo "$platforms" | while read -r p; do
            [ -n "$p" ] && _dry_run_msg "    - $p"
        done
    else
        python3 << PYEOF
import json
import re

# Load files
with open('$index_file') as f:
    catalog = json.load(f)

# Find the package
for pkg in catalog['packages']:
    if pkg['package'] != '$package':
        continue
    
    # Update each platform version
    for version_entry in pkg['versions']:
        if version_entry['platformVersion'] not in """$platforms""".split('\n'):
            continue
        
        print('  Updating platform: ' + version_entry['platformVersion'])
        
        # Update version and date
        version_entry['latestVersion'] = '$version'
        version_entry['updateDate'] = '$update_date'
        
        # Update URLs
        for binary in version_entry['binaries']:
            # Replace version in URL
            binary['url'] = re.sub(r'/0\.[0-9]+\.[0-9]+/', f'/$version/', binary['url'])

# Write updated catalog
with open('$index_file', 'w') as f:
    json.dump(catalog, f, indent=4)
PYEOF
    fi
    
    echo "✓ Catalog updated successfully"
    return 0
}

################################################################################
# Verification
################################################################################

function catalog_verify_render() {
    local repo_root="$1"
    local version="$2"
    local port="${3:-8000}"
    
    if [ -z "$repo_root" ] || [ -z "$version" ]; then
        echo "Usage: catalog_verify_render <repo_root> <version> [port]"
        return 1
    fi
    
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Would start HTTP server on port $port and verify version $version"
        _dry_run_msg "Would test catalog API for: \"latestVersion\": \"$version\""
        echo "✓ Catalog verification skipped (dry-run mode)"
        return 0
    fi
    
    echo "Starting HTTP server on port $port..."
    cd "$repo_root"
    timeout 15 python3 -m http.server "$port" > /tmp/catalog_server.log 2>&1 &
    local server_pid=$!
    
    sleep 2
    
    # Test API endpoint
    echo "Testing catalog API..."
    if ! curl -s "http://localhost:$port/index.json" | grep -q "\"latestVersion\": \"$version\""; then
        echo "ERROR: Version $version not found in rendered catalog"
        kill $server_pid 2>/dev/null || true
        return 1
    fi
    
    echo "✓ Catalog renders correctly with version $version"
    
    # Clean up server
    kill $server_pid 2>/dev/null || true
    sleep 1
    
    return 0
}

################################################################################
# Git Workflow
################################################################################

function catalog_git_workflow() {
    local repo_root="$1"
    local version="$2"
    local work_item="$3"
    local package="$4"
    local branch_template="$5"
    local commit_template="$6"
    
    if [ -z "$repo_root" ] || [ -z "$version" ] || [ -z "$work_item" ] || [ -z "$package" ] || [ -z "$branch_template" ] || [ -z "$commit_template" ]; then
        echo "Usage: catalog_git_workflow <repo_root> <version> <work_item> <package> <branch_template> <commit_template>"
        return 1
    fi
    
    cd "$repo_root"
    
    # Construct branch name and commit message
    local branch="${branch_template//\{VERSION\}/$version}"
    local commit_msg="${commit_template//\{VERSION\}/$version}"
    commit_msg="${commit_msg//\{WORK_ITEM\}/$work_item}"
    commit_msg="${commit_msg//\{PACKAGE\}/$package}"
    
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        _dry_run_msg "Would create release branch: $branch"
        _dry_run_msg "Would stage all changes"
        _dry_run_msg "Would commit with message: $commit_msg"
        _dry_run_msg "Would push to remote: origin/$branch"
        
        # Generate PR URL for preview
        local repo_url=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/.*://g')
        local pr_url="https://github.com/${repo_url}/pull/new/${branch}"
        
        echo ""
        echo "✓ Git workflow preview complete"
        echo "Preview PR URL: $pr_url"
        echo ""
        return 0
    fi
    
    echo "Creating release branch: $branch"
    git checkout -b "$branch" || { echo "ERROR: Failed to create branch"; return 1; }
    
    echo "Staging changes..."
    git add -A
    
    # Check if there are changes to commit
    if ! git diff --cached --quiet; then
        echo "Committing: $commit_msg"
        git commit -m "$commit_msg"
    else
        echo "WARNING: No changes to commit"
        return 1
    fi
    
    echo "Pushing to remote..."
    git push -u origin "$branch"
    
    # Generate PR URL
    local repo_url=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/.*://g')
    local pr_url="https://github.com/${repo_url}/pull/new/${branch}"
    
    echo ""
    echo "✓ Git workflow completed"
    echo "PR URL: $pr_url"
    echo ""
    
    return 0
}

################################################################################
# Complete Release Workflow
################################################################################

function catalog_release() {
    local manifest_file="$1"
    local version="$2"
    local work_item="$3"
    local update_date="$4"
    
    if [ -z "$manifest_file" ] || [ -z "$version" ] || [ -z "$work_item" ] || [ -z "$update_date" ]; then
        echo "Usage: catalog_release <manifest_file> <version> <work_item> <update_date>"
        echo ""
        echo "Example:"
        echo "  catalog_release manifests/blueprint.json 0.2.11 RLS-36424 2026-04-17"
        return 1
    fi
    
    local dry_run_label=""
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        dry_run_label=" [DRY-RUN]"
    fi
    
    echo "========================================"
    echo "Catalog Release Workflow${dry_run_label}"
    echo "========================================"
    echo "Version: $version"
    echo "Work Item: $work_item"
    echo "Release Date: $update_date"
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        echo "Mode: DRY-RUN (no changes will be committed)"
    fi
    echo ""
    
    catalog_validate_manifest "$manifest_file" || return 1
    echo ""
    
    catalog_download_assets "$manifest_file" "$version" || return 1
    echo ""
    
    catalog_update_json "$manifest_file" "$version" "$update_date" || return 1
    echo ""
    
    local repo_root=$(python3 -c "import json; print(json.load(open('$manifest_file'))['catalog']['repo_root'])")
    local package=$(python3 -c "import json; print(json.load(open('$manifest_file'))['package'])")
    local branch_template=$(python3 -c "import json; print(json.load(open('$manifest_file'))['release']['branch_template'])")
    local commit_template=$(python3 -c "import json; print(json.load(open('$manifest_file'))['release']['commit_message_template'])")
    
    catalog_git_workflow "$repo_root" "$version" "$work_item" "$package" "$branch_template" "$commit_template" || return 1
    
    echo "========================================"
    if [ "$CATALOG_DRY_RUN" = "1" ]; then
        echo "✓ Dry-run completed successfully!"
        echo "To execute the actual release, run:"
        echo "  CATALOG_DRY_RUN=0 catalog_release $manifest_file $version $work_item $update_date"
    else
        echo "✓ Release workflow completed successfully!"
    fi
    echo "========================================"
    
    return 0
}

# Export functions for sourcing
export -f catalog_check_environment
export -f catalog_validate_manifest
export -f catalog_download_assets
export -f catalog_update_json
export -f catalog_verify_render
export -f catalog_git_workflow
export -f catalog_release
