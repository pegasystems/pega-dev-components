#!/bin/bash

################################################################################
# Blueprint Component Catalog Release Wrapper
# Usage: ./blueprint_release.sh <version> <work_item> <release_date>
# Example: ./blueprint_release.sh 0.2.11 RLS-36424 2026-04-17
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="${REPO_ROOT}/manifests/blueprint.json"

# Source the shared library
source "${SCRIPT_DIR}/catalog_release_lib.sh"

################################################################################
# Argument Validation
################################################################################

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <version> <work_item> <release_date>"
    echo ""
    echo "Arguments:"
    echo "  version       - Semantic version (e.g., 0.2.11)"
    echo "  work_item     - Work item ID (e.g., RLS-36424)"
    echo "  release_date  - Release date in YYYY-MM-DD format (e.g., 2026-04-17)"
    echo ""
    echo "Example:"
    echo "  $0 0.2.11 RLS-36424 2026-04-17"
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
echo ""

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
echo "Next steps:"
echo "1. Open the PR URL in your browser"
echo "2. Review and merge the PR to 'main'"
echo "3. GitHub Pages will deploy automatically"
echo ""
