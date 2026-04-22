# Catalog Release Scripts

This directory contains the reusable catalog release workflow system.

## Overview

The catalog release system consists of three layers:

1. **Shared Library** (`catalog_release_lib.sh`) - Generic functions for any catalog
2. **Manifests** (`../manifests/`) - App-specific configuration (JSON)
3. **Wrappers** (`blueprint_release.sh`, `cdh_release.sh`, etc.) - Per-app entry points

## Quick Start

### Release Blueprint Component

```bash
./blueprint_release.sh 0.2.12 RLS-36425 2026-04-20
```

### Release CDH Component

```bash
./cdh_release.sh 0.0.2 RLS-36426 2026-04-20
```

### Dry-Run Mode (Preview Changes)

Preview a release without committing anything:

```bash
./blueprint_release.sh --dry-run 0.2.12 RLS-36425 2026-04-20
```

Dry-run will:
- ✓ Validate manifest and inputs
- ✓ Show what would be downloaded
- ✓ Show what would be updated in index.json
- ✓ Preview git branch and commit message
- ✓ Generate preview PR URL
- ✗ NOT download files
- ✗ NOT modify index.json
- ✗ NOT create git branch
- ✗ NOT push to remote

## What Happens

When you run a wrapper script:

1. ✓ **Validate** manifest and environment (checks `artifactory_key`)
2. ✓ **Download** binaries from Artifactory with version substitution
3. ✓ **Update** `index.json` with new version, date, and URLs
4. ✓ **Verify** the catalog renders correctly (HTTP server test)
5. ✓ **Git** workflow: branch, stage, commit, push
6. ✓ **Output** PR URL for final merge

## Adding a New Catalog

To release a new component catalog:

1. Create a manifest in `../manifests/my-app.json`:
   ```json
   {
     "app_name": "my-app",
     "package": "my-component",
     "platforms": ["23.1.0", "24.1.0"],
     "artifacts": {
       "base_url": "https://bin.pega.io/artifactory/repo2/.../x.x.x/",
       "files": [
         {"name": "my-artifact-x.x.x.jar", "platforms": ["23.1.0", "24.1.0"]}
       ]
     },
     "catalog": {
       "repo_root": "/path/to/pega-dev-components",
       "index_file": "index.json",
       "asset_path_template": "assets/components/{PACKAGE}/{VERSION}/"
     },
     "release": {
       "branch_template": "team/team-name/{VERSION}/release",
       "commit_message_template": "{WORK_ITEM} {PACKAGE} {VERSION}"
     }
   }
   ```

2. Create a wrapper script `my-app_release.sh`:
   ```bash
   #!/bin/bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   REPO_ROOT="$(dirname "$SCRIPT_DIR")"
   MANIFEST_FILE="${REPO_ROOT}/manifests/my-app.json"
   source "${SCRIPT_DIR}/catalog_release_lib.sh"
   # (same validation and call pattern as blueprint_release.sh)
   ```

3. Make it executable:
   ```bash
   chmod +x my-app_release.sh
   ```

4. Run it:
   ```bash
   ./my-app_release.sh 1.0.0 RLS-12345 2026-04-20
   ```

## Manifest Format

| Field | Description |
|-------|-------------|
| `app_name` | Human-readable app name (e.g., "blueprint") |
| `package` | Package ID in index.json (e.g., "platform-blueprint-component") |
| `platforms` | List of Pega platform versions supported |
| `artifacts.base_url` | Base URL for artifact downloads (use `x.x.x` for version placeholder) |
| `artifacts.files` | List of artifact file names and which platforms they support |
| `catalog.repo_root` | Absolute path to the catalog repo root |
| `catalog.index_file` | Path to index.json (relative to repo_root) |
| `catalog.asset_path_template` | Path template for assets (use `{PACKAGE}`, `{VERSION}` placeholders) |
| `release.branch_template` | Git branch template (use `{VERSION}` placeholder) |
| `release.commit_message_template` | Commit message template (use `{WORK_ITEM}`, `{PACKAGE}`, `{VERSION}` placeholders) |

## Library Functions

The shared library exports these functions for advanced usage:

- `catalog_check_environment()` - Verify required variables (artifactory_key, etc.)
- `catalog_validate_manifest(manifest_file)` - Validate manifest JSON
- `catalog_download_assets(manifest_file, version)` - Download binaries from Artifactory
- `catalog_update_json(manifest_file, version, update_date)` - Update index.json
- `catalog_verify_render(repo_root, version, [port])` - Verify catalog renders correctly
- `catalog_git_workflow(repo_root, version, work_item, branch_template, commit_template)` - Handle git operations
- `catalog_release(manifest_file, version, work_item, update_date)` - Full end-to-end workflow

### Example: Custom Release Logic

```bash
#!/bin/bash
source ./scripts/catalog_release_lib.sh

# Custom pre-checks
echo "Running custom pre-release checks..."

# Download assets
catalog_download_assets manifests/my-app.json 1.0.0

# Run custom tests
run_my_tests

# Update catalog
catalog_update_json manifests/my-app.json 1.0.0 2026-04-20

# Continue with git
catalog_git_workflow /path/to/repo 1.0.0 RLS-12345 "team/{VERSION}/release" "{WORK_ITEM} release"
```

## Environment Setup

Before running any script, ensure:

```bash
export artifactory_key="your-artifactory-token"
```

If you have this set in your bash environment already, the scripts will use it automatically.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `artifactory_key needs to be set` | Run `export artifactory_key="your-token"` |
| `Manifest file not found` | Check manifest path in wrapper script |
| `Failed to download artifact` | Check Artifactory URL and token permissions |
| `Version not found in rendered catalog` | Check `catalog_update_json` function and JSON syntax |
| `Git push fails` | Ensure remote is configured and you have push permissions |

## Future Enhancements

- [x] Add `--dry-run` flag to preview changes without committing
- [ ] Add changelog generation from commit history
- [ ] Add smoke tests for downloaded artifacts (SHA256 verification)
- [ ] Support for multiple artifacts per platform
- [ ] Automated PR merge option for CI/CD pipelines
- [ ] Rollback functionality to revert a release

## Dry-Run Mode Details

The `--dry-run` flag enables safe preview mode:

### How to Use

```bash
# Preview a release without any side effects
./blueprint_release.sh --dry-run 0.2.12 RLS-36425 2026-04-20
```

### What Dry-Run Does

| Operation | Normal | Dry-Run |
|-----------|--------|---------|
| Validate manifest | ✓ | ✓ |
| Check environment | ✓ | ✓ |
| Download artifacts | ✓ | ✗ (shows what would be downloaded) |
| Update index.json | ✓ | ✗ (shows what would be updated) |
| Start HTTP server | ✓ | ✗ (shows what would be tested) |
| Create git branch | ✓ | ✗ (shows branch name) |
| Commit changes | ✓ | ✗ (shows commit message) |
| Push to remote | ✓ | ✗ (shows PR URL) |

### Workflow Example

```bash
# 1. Preview the release first
./blueprint_release.sh --dry-run 0.2.12 RLS-36425 2026-04-20

# Output shows what will happen...
# [DRY-RUN] Would download assets to: ...
# [DRY-RUN] Would update catalog with: Version: 0.2.12, Date: 2026-04-20
# [DRY-RUN] Would create release branch: team/planetexpress/0.2.12/release
# [DRY-RUN] Would commit with message: RLS-36425 platform-blueprint-component 0.2.12
# Preview PR URL: https://github.com/pegasystems/pega-dev-components/pull/new/team/planetexpress/0.2.12/release

# 2. Once satisfied, run the actual release
./blueprint_release.sh 0.2.12 RLS-36425 2026-04-20

# 3. Follow the next steps to merge the PR
```

### Using Dry-Run in Scripts

```bash
#!/bin/bash

# Set dry-run mode
export CATALOG_DRY_RUN=1

# Import library
source scripts/catalog_release_lib.sh

# Run with dry-run enabled
catalog_release manifests/blueprint.json 0.2.12 RLS-36425 2026-04-20

# Later, disable dry-run for actual release
export CATALOG_DRY_RUN=0
catalog_release manifests/blueprint.json 0.2.12 RLS-36425 2026-04-20
```
