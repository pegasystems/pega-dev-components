#!/bin/bash

################################################################################
# Blueprint Component Catalog Release Wrapper
# Usage: ./blueprint_release.sh [--dry-run] [--no-commit] <version> <work_item> <release_date>
# Example: ./blueprint_release.sh 0.2.11 RLS-36424 2026-04-17
# Dry-run: ./blueprint_release.sh --dry-run 0.2.11 RLS-36424 2026-04-17
# No-commit: ./blueprint_release.sh --no-commit 0.2.11 RLS-36424 2026-04-17
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="${REPO_ROOT}/manifests/blueprint.json"

# Check for --dry-run and --no-commit flags
DRY_RUN=0
NO_COMMIT=0
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=1
    shift  # Remove --dry-run from arguments
fi

if [ "$1" = "--no-commit" ]; then
    NO_COMMIT=1
    shift  # Remove --no-commit from arguments
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

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 [--dry-run] [--no-commit] <version> <work_item> <release_date>"
    echo ""
    echo "Arguments:"
    echo "  version       - Semantic version (e.g., 0.2.11)"
    echo "  work_item     - Work item ID (e.g., RLS-36424)"
    echo "  release_date  - Release date in YYYY-MM-DD format (e.g., 2026-04-17)"
    echo ""
    echo "Options:"
    echo "  --dry-run     - Preview changes without committing"
    echo "  --no-commit   - Stage and commit manually (skip auto-push)"
    echo ""
    echo "Examples:"
    echo "  $0 0.2.11 RLS-36424 2026-04-17"
    echo "  $0 --dry-run 0.2.11 RLS-36424 2026-04-17"
    echo "  $0 --no-commit 0.2.11 RLS-36424 2026-04-17"
    echo ""
    exit 1
fi

VERSION="$1"
WORK_ITEM="$2"
RELEASE_DATE="$3"

# Validate version format (simple check)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid version format: $VERSION (expected: x.y.z)"
    exit 1
fi

# Validate work item format
if ! [[ "$WORK_ITEM" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "ERROR: Invalid work item format: $WORK_ITEM (expected: ABC-12345)"
    exit 1
fi

# Validate date format
if ! [[ "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: Invalid date format: $RELEASE_DATE (expected: YYYY-MM-DD)"
    exit 1
fi

################################################################################
# Execute Release
################################################################################

echo "BluePrint Component Catalog Release"
echo "===================================="
if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY-RUN MODE]"
    echo ""
fi

# Check manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: Manifest not found: $MANIFEST_FILE"
    exit 1
fi

# Run the complete release workflow
if ! catalog_release "$MANIFEST_FILE" "$VERSION" "$WORK_ITEM" "$RELEASE_DATE"; then
    echo ""
    echo "ERROR: Release workflow failed"
    exit 1
fi

echo ""
if [ $DRY_RUN -eq 0 ]; then
    echo "Next steps:"
    echo "1. Open the PR URL in your browser"
    echo "2. Review and merge the PR to 'main'"
    echo "3. GitHub Pages will deploy automatically"
else
    echo "To execute the actual release, run:"
    echo "./blueprint_release.sh $VERSION $WORK_ITEM $RELEASE_DATE"
fi
echo ""
