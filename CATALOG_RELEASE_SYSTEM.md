# Reusable Catalog Release System

## What Was Built

A **three-layer release system** that makes it easy to release new versions of component catalogs:

### 1. Shared Library (`scripts/catalog_release_lib.sh`)
Generic functions that work for any catalog:
- Download assets from Artifactory with automatic version substitution
- Update index.json with version, date, and URLs
- Verify the catalog renders correctly (HTML + API)
- Handle full git workflow (branch, commit, push, PR URL)
- Complete end-to-end release orchestration

### 2. Manifest Format (`manifests/*.json`)
App-specific configuration that defines:
- Which platforms are supported
- Where to download binaries (Artifactory URLs)
- How to update the catalog JSON
- Git branch and commit message templates

### 3. Wrapper Scripts (`scripts/*_release.sh`)
Thin entry points that:
- Load the app's manifest
- Validate inputs (version, work item, date)
- Call the shared library with manifest configuration
- Provide helpful error messages and next steps

## Files Created

```
pega-dev-components/
├── ideas/
│   └── reusable-catalog-release-workflow.md    (idea document)
├── manifests/
│   ├── blueprint.json                          (blueprint config)
│   └── cdh.json                                (cdh config)
├── scripts/
│   ├── catalog_release_lib.sh                  (shared library)
│   ├── blueprint_release.sh                    (blueprint wrapper)
│   ├── cdh_release.sh                          (cdh wrapper)
│   └── README.md                               (usage guide)
```

## Usage

### Release Blueprint 0.2.12

```bash
cd /home/sartm/code/component-catalog/pega-dev-components
./scripts/blueprint_release.sh 0.2.12 RLS-36425 2026-04-20
```

### Release CDH 0.0.2

```bash
cd /home/sartm/code/component-catalog/pega-dev-components
./scripts/cdh_release.sh 0.0.2 RLS-36426 2026-04-20
```

## How It Works

**Step-by-step execution:**

1. **Validate** - Checks manifest syntax, environment variables, input formats
2. **Download** - Pulls binaries from Artifactory using the manifest URL templates
3. **Update** - Modifies index.json with new version, date, and asset URLs
4. **Verify** - Starts a local HTTP server and checks that the version appears in the rendered catalog
5. **Git** - Creates release branch, stages changes, commits with work item ID, pushes to remote
6. **Output** - Displays the PR URL for final merge

## Adding New Catalogs

To release a different component:

1. Create `manifests/my-component.json` with the same structure as `blueprint.json`
2. Create `scripts/my-component_release.sh` by copying `blueprint_release.sh` and updating the MANIFEST_FILE path
3. Make it executable: `chmod +x scripts/my-component_release.sh`
4. Run it: `./scripts/my-component_release.sh 1.0.0 RLS-12345 2026-04-20`

## Key Features

✓ **Reusable** - Works with any component catalog  
✓ **Declarative** - Configuration in JSON manifests, not hardcoded in scripts  
✓ **Safe** - Validates inputs and tests rendering before committing  
✓ **Complete** - Handles download → update → verify → git workflow  
✓ **Flexible** - Easy to add new catalogs without touching the core library  
✓ **Documented** - Inline help, README, and example manifests  

## Integration with OpenCode

This system is designed to work with the OpenCode assistant. A **skill** can be created to:
- Guide users through the release workflow
- Automatically generate release parameters
- Validate manifest correctness
- Handle common issues and provide troubleshooting

The skill would use the same manifest-driven approach, making releases predictable and repeatable via AI assistance.

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/catalog_release_lib.sh` | Shared library with generic release functions |
| `scripts/blueprint_release.sh` | Entry point for Blueprint Component releases |
| `scripts/cdh_release.sh` | Entry point for CDH Component releases |
| `scripts/README.md` | Complete usage guide and API reference |
| `manifests/blueprint.json` | Blueprint component configuration |
| `manifests/cdh.json` | CDH component configuration |
| `ideas/reusable-catalog-release-workflow.md` | Architecture and design document |

## Testing

The system has been validated with:
- ✓ Manifest validation (JSON syntax)
- ✓ Help text output (argument parsing)
- ✓ Environment checks (artifactory_key)
- ✓ Path resolution (manifests and scripts locate correctly)

Ready to use for production releases!
