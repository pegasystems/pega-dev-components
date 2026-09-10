#!/bin/bash

# CS Blueprint Component Catalog Release Wrapper
# Usage: ./cs_blueprint_release.sh [--dry-run] [--no-commit] [--artifact-path <path>] <version> <work_item> <release_date>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="${REPO_ROOT}/manifests/cs-blueprint.json"
DRY_RUN=0
NO_COMMIT=0
ARTIFACT_PATH=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-commit)
            NO_COMMIT=1
            shift
            ;;
        --artifact-path)
            if [ -z "$2" ]; then
                echo "ERROR: --artifact-path requires a file path"
                exit 1
            fi
            ARTIFACT_PATH="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

source "${SCRIPT_DIR}/catalog_release_lib.sh"

if [ "$DRY_RUN" -eq 1 ]; then
    export CATALOG_DRY_RUN=1
fi

if [ "$NO_COMMIT" -eq 1 ]; then
    export CATALOG_NO_COMMIT=1
fi

if [ -n "$ARTIFACT_PATH" ]; then
    export CATALOG_LOCAL_ARTIFACT="$ARTIFACT_PATH"
fi

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 [--dry-run] [--no-commit] [--artifact-path <path>] <version> <work_item> <release_date>"
    exit 1
fi

VERSION="$1"
WORK_ITEM="$2"
RELEASE_DATE="$3"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid version format: $VERSION (expected: x.y.z)"
    exit 1
fi

if ! [[ "$WORK_ITEM" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "ERROR: Invalid work item format: $WORK_ITEM (expected: ABC-12345)"
    exit 1
fi

if ! [[ "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: Invalid date format: $RELEASE_DATE (expected: YYYY-MM-DD)"
    exit 1
fi

echo "CS Blueprint Component Catalog Release"
echo "======================================"

if ! catalog_release "$MANIFEST_FILE" "$VERSION" "$WORK_ITEM" "$RELEASE_DATE"; then
    echo "ERROR: Release workflow failed"
    exit 1
fi
