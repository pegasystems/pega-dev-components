#!/bin/bash

################################################################################
# GenAI (AI Authoring Rules) Component Catalog Release Wrapper
#
# Usage:
#   ./genai_release.sh [--dry-run] [--no-commit] \
#       [--skill-version <v>] [--mcp-version <v>] [--autopilot-version <v>] \
#       [--autopilot-dependent true|false] \
#       <rules_version> <work_item> <release_date>
#
# Arguments:
#   rules_version         - Version of the GenAI rules bundle (e.g., 0.0.24)
#   work_item             - Work item ID (e.g., RLS-99999)
#   release_date          - Release date in YYYY-MM-DD format (e.g., 2026-07-09)
#
# Options:
#   --dry-run             - Preview changes without writing or committing
#   --no-commit           - Stage changes locally, skip commit/push
#   --skill-version <v>   - Also update latestSkillVersion to <v>
#   --mcp-version <v>     - Also update latestMcpVersion to <v>
#   --autopilot-version <v> - Also update latestAutopilotVersion to <v>
#                             (automatically sets isAutopilotDependent=true unless
#                              --autopilot-dependent is explicitly provided)
#   --autopilot-dependent true|false
#                         - Explicitly set the isAutopilotDependent flag
#
# Examples:
#   # Rules-only release (no cross-component dependency)
#   ./genai_release.sh 0.0.24 RLS-99999 2026-07-09
#
#   # Rules release that also requires a new autopilot version
#   ./genai_release.sh --autopilot-version 1.2.0 0.0.24 RLS-99999 2026-07-09
#
#   # Full release updating all sub-components
#   ./genai_release.sh \
#     --skill-version 2.1.0 --mcp-version 1.0.5 --autopilot-version 1.2.0 \
#     --autopilot-dependent true \
#     0.0.24 RLS-99999 2026-07-09
#
#   # Dry-run preview
#   ./genai_release.sh --dry-run 0.0.24 RLS-99999 2026-07-09
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="${REPO_ROOT}/manifests/ai-authoring-rules.json"

################################################################################
# Parse flags (all options before positional args)
################################################################################

DRY_RUN=0
NO_COMMIT=0
SKILL_VERSION=""
MCP_VERSION=""
AUTOPILOT_VERSION=""
AUTOPILOT_DEPENDENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-commit)
            NO_COMMIT=1
            shift
            ;;
        --skill-version)
            SKILL_VERSION="$2"
            shift 2
            ;;
        --mcp-version)
            MCP_VERSION="$2"
            shift 2
            ;;
        --autopilot-version)
            AUTOPILOT_VERSION="$2"
            shift 2
            ;;
        --autopilot-dependent)
            AUTOPILOT_DEPENDENT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Remaining positional args
RULES_VERSION="${1:-}"
WORK_ITEM="${2:-}"
RELEASE_DATE="${3:-}"

# If autopilot-version provided but autopilot-dependent not explicitly set,
# infer isAutopilotDependent=true automatically
if [ -n "$AUTOPILOT_VERSION" ] && [ -z "$AUTOPILOT_DEPENDENT" ]; then
    AUTOPILOT_DEPENDENT="true"
fi

# Source the shared library
source "${SCRIPT_DIR}/catalog_release_lib.sh"

# Set environment variables for modes
if [ $DRY_RUN -eq 1 ]; then
    export CATALOG_DRY_RUN=1
fi

if [ $NO_COMMIT -eq 1 ]; then
    export CATALOG_NO_COMMIT=1
fi

################################################################################
# Argument Validation
################################################################################

if [ -z "$RULES_VERSION" ] || [ -z "$WORK_ITEM" ] || [ -z "$RELEASE_DATE" ]; then
    echo "Usage: $0 [options] <rules_version> <work_item> <release_date>"
    echo ""
    echo "Arguments:"
    echo "  rules_version               - Rules bundle version (e.g., 0.0.24)"
    echo "  work_item                   - Work item ID (e.g., RLS-99999)"
    echo "  release_date                - Date in YYYY-MM-DD format (e.g., 2026-07-09)"
    echo ""
    echo "Options:"
    echo "  --dry-run                   - Preview changes without committing"
    echo "  --no-commit                 - Stage and commit manually (skip auto-push)"
    echo "  --skill-version <v>         - Also update latestSkillVersion"
    echo "  --mcp-version <v>           - Also update latestMcpVersion"
    echo "  --autopilot-version <v>     - Also update latestAutopilotVersion"
    echo "                                (auto-sets isAutopilotDependent=true)"
    echo "  --autopilot-dependent <v>   - Explicitly set isAutopilotDependent (true|false)"
    echo ""
    echo "Examples:"
    echo "  $0 0.0.24 RLS-99999 2026-07-09"
    echo "  $0 --autopilot-version 1.2.0 0.0.24 RLS-99999 2026-07-09"
    echo "  $0 --dry-run 0.0.24 RLS-99999 2026-07-09"
    echo ""
    exit 1
fi

# Validate version formats
validate_version() {
    local label="$1"
    local value="$2"
    if ! [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: Invalid version format for $label: $value (expected: x.y.z)"
        exit 1
    fi
}

validate_version "rules_version" "$RULES_VERSION"
[ -n "$SKILL_VERSION" ]     && validate_version "--skill-version"     "$SKILL_VERSION"
[ -n "$MCP_VERSION" ]       && validate_version "--mcp-version"       "$MCP_VERSION"
[ -n "$AUTOPILOT_VERSION" ] && validate_version "--autopilot-version" "$AUTOPILOT_VERSION"

if ! [[ "$WORK_ITEM" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "ERROR: Invalid work item format: $WORK_ITEM (expected: ABC-12345)"
    exit 1
fi

if ! [[ "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: Invalid date format: $RELEASE_DATE (expected: YYYY-MM-DD)"
    exit 1
fi

if [ -n "$AUTOPILOT_DEPENDENT" ] && [ "$AUTOPILOT_DEPENDENT" != "true" ] && [ "$AUTOPILOT_DEPENDENT" != "false" ]; then
    echo "ERROR: --autopilot-dependent must be 'true' or 'false', got: $AUTOPILOT_DEPENDENT"
    exit 1
fi

################################################################################
# Execute Release
################################################################################

DRY_RUN_LABEL=""
[ $DRY_RUN -eq 1 ] && DRY_RUN_LABEL=" [DRY-RUN]"
NO_COMMIT_LABEL=""
[ $NO_COMMIT -eq 1 ] && NO_COMMIT_LABEL=" [NO-COMMIT]"

echo "GenAI (AI Authoring Rules) Component Catalog Release${DRY_RUN_LABEL}${NO_COMMIT_LABEL}"
echo "======================================================"
echo "latestRulesVersion : $RULES_VERSION"
[ -n "$SKILL_VERSION" ]       && echo "latestSkillVersion    : $SKILL_VERSION"
[ -n "$MCP_VERSION" ]         && echo "latestMcpVersion      : $MCP_VERSION"
[ -n "$AUTOPILOT_VERSION" ]   && echo "latestAutopilotVersion: $AUTOPILOT_VERSION"
[ -n "$AUTOPILOT_DEPENDENT" ] && echo "isAutopilotDependent  : $AUTOPILOT_DEPENDENT"
echo "Work Item          : $WORK_ITEM"
echo "Release Date       : $RELEASE_DATE"
echo ""

# Check manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: Manifest not found: $MANIFEST_FILE"
    exit 1
fi

# Step 1: Validate manifest
catalog_validate_manifest "$MANIFEST_FILE" || exit 1
echo ""

# Step 2: Download assets (keyed on rules version — the primary artifact)
catalog_download_assets "$MANIFEST_FILE" "$RULES_VERSION" || exit 1
echo ""

# Step 3: Update catalog JSON with genai-specific version fields
catalog_update_genai_json \
    "$MANIFEST_FILE" \
    "$RELEASE_DATE" \
    "$RULES_VERSION" \
    "$SKILL_VERSION" \
    "$MCP_VERSION" \
    "$AUTOPILOT_VERSION" \
    "$AUTOPILOT_DEPENDENT" || exit 1
echo ""

# Step 4: Verify the rendered catalog reflects the new rules version
REPO_ROOT_FROM_MANIFEST=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE'))['catalog']['repo_root'])")
catalog_verify_genai_render "$REPO_ROOT_FROM_MANIFEST" "$RULES_VERSION" || exit 1
echo ""

# Step 5: Git branch, commit, push
PACKAGE=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE'))['package'])")
BRANCH_TEMPLATE=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE'))['release']['branch_template'])")
COMMIT_TEMPLATE=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE'))['release']['commit_message_template'])")

catalog_git_workflow \
    "$REPO_ROOT_FROM_MANIFEST" \
    "$RULES_VERSION" \
    "$WORK_ITEM" \
    "$PACKAGE" \
    "$BRANCH_TEMPLATE" \
    "$COMMIT_TEMPLATE" || exit 1

echo ""
if [ $DRY_RUN -eq 0 ] && [ $NO_COMMIT -eq 0 ]; then
    echo "Next steps:"
    echo "1. Open the PR URL in your browser"
    echo "2. Review and merge the PR to 'main'"
    echo "3. GitHub Pages will deploy automatically"
else
    REPLAY_CMD="./genai_release.sh"
    [ -n "$SKILL_VERSION" ]       && REPLAY_CMD="$REPLAY_CMD --skill-version $SKILL_VERSION"
    [ -n "$MCP_VERSION" ]         && REPLAY_CMD="$REPLAY_CMD --mcp-version $MCP_VERSION"
    [ -n "$AUTOPILOT_VERSION" ]   && REPLAY_CMD="$REPLAY_CMD --autopilot-version $AUTOPILOT_VERSION"
    [ -n "$AUTOPILOT_DEPENDENT" ] && REPLAY_CMD="$REPLAY_CMD --autopilot-dependent $AUTOPILOT_DEPENDENT"
    REPLAY_CMD="$REPLAY_CMD $RULES_VERSION $WORK_ITEM $RELEASE_DATE"
    echo "To execute the actual release, run:"
    echo "$REPLAY_CMD"
fi
echo ""
