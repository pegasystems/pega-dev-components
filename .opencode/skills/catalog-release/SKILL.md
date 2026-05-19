---
name: catalog-release
description: Release components to the Pega Dev Components catalog. Use when the user asks to "publish", "release", or "deploy" a component like Blueprint or CDH, or wants to walk through the release process.
metadata:
  audience: personal
  workflow: release
tools:
  - bash
  - read
---

# Catalog Release Skill

Release components to the Pega Dev Components catalog hosted on GitHub Pages.

## Supported Components

| Component | Package | Script |
|-----------|---------|--------|
| Blueprint | `platform-blueprint-component` | `./scripts/blueprint_release.sh` |
| CDH | `cdh-blueprint-component` | `./scripts/cdh_release.sh` |

## Prerequisites

Before releasing, ensure:

1. **Artifactory key is set:**
   ```bash
   export artifactory_key="your-artifactory-token"
   ```

2. **Working directory** is `pega-dev-components` repo

3. **Have a work item ID** (e.g., `RLS-XXXXX`)

---

## Workflows

### Release a Component

Trigger: "release blueprint 0.2.13", "publish CDH 0.0.2", "deploy blueprint"

1. **Identify component and version** from user request
2. **Ask for work item ID** if not provided (format: `RLS-XXXXX`)
3. **Determine release date** - default to today's date (YYYY-MM-DD)
4. **Recommend dry-run first:**
   ```bash
   ./scripts/<component>_release.sh --dry-run <version> <work_item> <date>
   ```
5. **Run actual release** after user confirms:
   ```bash
   ./scripts/<component>_release.sh <version> <work_item> <date>
   ```
6. **Verify the release** after completion:
   ```bash
   source scripts/catalog_release_lib.sh
   catalog_verify_render "$(pwd)" "<version>"
   ```
7. **Validate URLs** have correct filenames:
   ```bash
   python3 -c "
   import json
   with open('index.json') as f:
       data = json.load(f)
   pkg = [p for p in data['packages'] if p['package'] == '<package>'][0]
   for v in pkg['versions']:
       url = v['binaries'][0]['url']
       version = v['latestVersion']
       ok = f'-{version}-' in url and f'/{version}/' in url
       print(f\"{'✓' if ok else '✗'} {v['platformVersion']}: {url.split('/')[-1]}\")"
   ```
8. **Provide PR URL** for user to review and merge

### Dry-Run Release

Trigger: "dry-run release", "preview release", "test release"

1. Run with `--dry-run` flag
2. Explain what would happen without making changes
3. Show: downloads, catalog updates, branch name, commit message, PR URL

### Verify a Release

Trigger: "verify release", "validate catalog", "check release"

1. **Check version in catalog:**
   ```bash
   source scripts/catalog_release_lib.sh
   catalog_verify_render "$(pwd)" "<version>"
   ```

2. **Validate URL filenames match version:**
   ```bash
   python3 -c "
   import json
   with open('index.json') as f:
       data = json.load(f)
   pkg = [p for p in data['packages'] if p['package'] == '<package>'][0]
   for v in pkg['versions']:
       url = v['binaries'][0]['url']
       version = v['latestVersion']
       filename_ok = f'-{version}-' in url
       path_ok = f'/{version}/' in url
       status = '✓' if (filename_ok and path_ok) else '✗'
       print(f\"{status} {v['platformVersion']}: {url.split('/')[-1].replace('?download=', '')}\")"
   ```

### Pull and Merge Updates

Trigger: "pull latest", "update branch", "merge main"

When branch needs updates from main:

```bash
git pull origin main --no-edit
```

If conflicts occur:
1. Check conflicted files: `git diff --name-only --diff-filter=U`
2. For `index.json` conflicts, prefer our changes (HEAD) for version/URL updates:
   ```bash
   git checkout --ours index.json && git add index.json
   ```
3. Complete merge: `git commit --no-edit`
4. Push: `git push`

### Check Release Status

Trigger: "release status", "what's deployed", "current versions"

Query current catalog state:

```bash
python3 -c "
import json
with open('index.json') as f:
    data = json.load(f)
for pkg in data['packages']:
    print(f\"\n{pkg['package']}:\")
    for v in pkg['versions']:
        print(f\"  {v['platformVersion']}: {v['latestVersion']} ({v['updateDate']})\")"
```

---

## Release Script Details

### What the Script Does

| Step | Action |
|------|--------|
| 1 | Validates inputs and manifest syntax |
| 2 | Downloads artifacts from Artifactory for all platforms |
| 3 | Updates `index.json` with version, date, and URLs (path + filename) |
| 4 | Starts local HTTP server and verifies version appears |
| 5 | Creates release branch (e.g., `team/planetexpress/0.2.13/release`) |
| 6 | Commits with message `<WORK_ITEM> <PACKAGE> <VERSION>` |
| 7 | Pushes branch to remote |
| 8 | Outputs PR URL |

### Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Preview what would happen without making changes |
| `--no-commit` | Stage changes locally, push manually later |

### After Merge

Once PR is merged to `main`, GitHub Actions automatically deploys to:
**https://pegasystems.github.io/pega-dev-components/**

---

## Platform Versions

Blueprint supports: 23.1.0, 24.1.0, 24.2.0, 25.1.0, 26.1.0

JAR variants:
- `blueprint-<version>-bundle.jar` - for 23.1.0, 24.1.0, 24.2.0
- `blueprint-<version>-bundle-jakarta.jar` - for 25.1.0, 26.1.0

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `artifactory_key needs to be set` | `export artifactory_key="your-token"` |
| Download fails | Check Artifactory URL and token permissions |
| Version not in catalog | Check `catalog_update_json` and JSON syntax |
| Filename mismatch in URL | Script should update both path and filename; verify with validation |
| Git push fails | Check remote config and push permissions |
| Merge conflicts | Usually in `index.json`; keep our (HEAD) changes for version updates |

---

## Adding a New Component

1. Create manifest: `manifests/my-component.json`
2. Create wrapper: `scripts/my-component_release.sh` (copy from existing)
3. Make executable: `chmod +x scripts/my-component_release.sh`
4. Update this skill's "Supported Components" table

---

## Rules

- Always recommend dry-run before actual release
- Always verify after release completes
- Provide PR URL for user to review and merge
- Default release date to today if not specified
- Work item ID is required (format: `RLS-XXXXX`)
