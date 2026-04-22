---
title: Reusable Catalog Release Workflow
status: in-progress
ai-instructions: |
  Build a generic catalog release library + per-app wrapper system to allow any component catalog to release assets efficiently.
  - Create shared library script with generic functions (download, update JSON, verify, commit/PR)
  - Design manifest format for app-specific configuration
  - Implement blueprint and cdh wrapper scripts as reference implementations
  - Goal: one-command release that handles download, update, verify, branch, commit, and push
---

# Reusable Catalog Release Workflow

## Problem
Currently, releasing a new catalog version requires:
1. Manual binary download from Artifactory
2. Manual JSON editing for each platform version
3. Manual local verification
4. Manual git branch/commit/push workflow

This is tedious, error-prone, and hard to scale to other component catalogs.

## Solution
Build a **shared library + per-app wrapper system** so any catalog can execute a single command:
```bash
./blueprint_release.sh 0.2.11 RLS-36424 2026-04-17
```

## Architecture

### Layer 1: Shared Library (`catalog_release_lib.sh`)
Generic functions usable by any app:
- `catalog_download_assets` - fetch binaries from Artifactory with version substitution
- `catalog_update_json` - apply version/date updates to index.json using manifest rules
- `catalog_verify_render` - spin up HTTP server and check rendered version appears
- `catalog_git_workflow` - create branch, commit, push, and generate PR instructions

### Layer 2: Manifest Format
Per-app YAML/JSON config defining:
- `package_name` - e.g., `platform-blueprint-component`
- `artifact_urls` - base URL templates for downloads
- `artifact_files` - list of files to download per version
- `json_updates` - rules for updating index.json by platform version
- `release_branch_template` - e.g., `team/planetexpress/{VERSION}/release`
- `commit_message_template` - e.g., `{WORK_ITEM} {PACKAGE} {VERSION}`

### Layer 3: Per-App Wrappers
Thin scripts that invoke the shared library with app-specific manifest:
- `blueprint_release.sh` - wraps blueprint manifest
- `cdh_release.sh` - wraps CDH manifest
- `[new_app]_release.sh` - easily added for other catalogs

## Implementation Plan

### Phase 1: Shared Library
Create `catalog_release_lib.sh` with these functions:
- Environment checks (artifactory_key, git config)
- Asset download with retry/validation
- JSON update (version, date, URLs) targeting specific package entries
- Local render verification (HTTP server + grep for version string)
- Git workflow (branch creation, staging, commit, push)
- PR generation (URL or CLI)

### Phase 2: Manifest Format
Define JSON schema for app configuration:
```json
{
  "app_name": "blueprint",
  "package": "platform-blueprint-component",
  "platforms": ["23.1.0", "24.1.0", "24.2.0", "25.1.0", "26.1.0"],
  "artifacts": {
    "base_url": "https://bin.pega.io/artifactory/repo2/com/pega/infinity/component/blueprint/x.x.x/",
    "files": [
      {"name": "blueprint-x.x.x-bundle.jar", "platforms": ["23.1.0", "24.1.0", "24.2.0"]},
      {"name": "blueprint-x.x.x-bundle-jakarta.jar", "platforms": ["25.1.0", "26.1.0"]}
    ]
  },
  "catalog": {
    "repo_root": "/home/sartm/code/component-catalog/pega-dev-components",
    "index_file": "index.json",
    "asset_path_template": "assets/components/{PACKAGE}/{VERSION}/"
  },
  "release": {
    "branch_template": "team/planetexpress/{VERSION}/release",
    "commit_message_template": "{WORK_ITEM} {PACKAGE} {VERSION}"
  }
}
```

### Phase 3: Per-App Wrappers
Create minimal wrapper scripts that load manifest + call library:
- Load manifest JSON
- Validate inputs (version, work item, date)
- Call library functions in sequence
- Report success/failure

### Phase 4: Testing
Test with:
- Existing 0.2.10 release (does it match current structure?)
- New 0.2.11 release (already done manually; can we replicate?)
- CDH catalog (different artifact structure)

## Success Criteria
- [ ] One-command release workflow works end-to-end
- [ ] No hardcoded paths/filenames in library
- [ ] Manifest format is flexible enough for blueprint + CDH
- [ ] Easy to add new catalogs without script changes
- [ ] Version string appears in rendered HTML after release
- [ ] All tests pass

## Future Enhancements
- Create a skill to encode the release procedure for AI assistance
- Add automated changelog generation
- Add smoke tests for download integrity
- Support for multi-artifact per platform
- Dry-run mode before actual release
