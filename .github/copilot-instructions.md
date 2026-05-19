# Catalog Release Instructions

This repository hosts the Pega Dev Components catalog on GitHub Pages.

## Releasing Components

### Supported Components

| Component | Package | Script |
|-----------|---------|--------|
| Blueprint | `platform-blueprint-component` | `./scripts/blueprint_release.sh` |
| CDH | `cdh-blueprint-component` | `./scripts/cdh_release.sh` |

### Prerequisites

```bash
export artifactory_key="your-artifactory-token"
```

### Release Command

```bash
./scripts/blueprint_release.sh <version> <work_item> <release_date>

# Example:
./scripts/blueprint_release.sh 0.2.13 RLS-37288 2026-05-19
```

### Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Preview what would happen without making changes |
| `--no-commit` | Stage changes locally, push manually later |

### Recommended Workflow

1. **Dry-run first:**
   ```bash
   ./scripts/blueprint_release.sh --dry-run 0.2.13 RLS-37288 2026-05-19
   ```

2. **Run actual release:**
   ```bash
   ./scripts/blueprint_release.sh 0.2.13 RLS-37288 2026-05-19
   ```

3. **Verify the release:**
   ```bash
   source scripts/catalog_release_lib.sh
   catalog_verify_render "$(pwd)" "0.2.13"
   ```

4. **Validate URLs:**
   ```bash
   python3 -c "
   import json
   with open('index.json') as f:
       data = json.load(f)
   pkg = [p for p in data['packages'] if p['package'] == 'platform-blueprint-component'][0]
   for v in pkg['versions']:
       url = v['binaries'][0]['url']
       version = v['latestVersion']
       ok = f'-{version}-' in url and f'/{version}/' in url
       print(f\"{'✓' if ok else '✗'} {v['platformVersion']}: {url.split('/')[-1]}\")"
   ```

5. **Create PR** from the output URL, get approval, and merge to `main`

### What the Script Does

1. Validates inputs and manifest syntax
2. Downloads artifacts from Artifactory for all platforms
3. Updates `index.json` with version, date, and URLs (path + filename)
4. Creates release branch (e.g., `team/planetexpress/0.2.13/release`)
5. Commits with message `<WORK_ITEM> <PACKAGE> <VERSION>`
6. Pushes branch and outputs PR URL

### After Merge

GitHub Actions automatically deploys to:
https://pegasystems.github.io/pega-dev-components/

## Key Files

| File | Purpose |
|------|---------|
| `scripts/catalog_release_lib.sh` | Shared release functions |
| `scripts/blueprint_release.sh` | Blueprint release wrapper |
| `scripts/cdh_release.sh` | CDH release wrapper |
| `manifests/blueprint.json` | Blueprint release config |
| `manifests/cdh.json` | CDH release config |
| `index.json` | Catalog API source |

## Platform Versions

Blueprint supports: 23.1.0, 24.1.0, 24.2.0, 25.1.0, 26.1.0

JAR variants:
- `blueprint-<version>-bundle.jar` - for 23.1.0, 24.1.0, 24.2.0
- `blueprint-<version>-bundle-jakarta.jar` - for 25.1.0, 26.1.0

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `artifactory_key needs to be set` | `export artifactory_key="your-token"` |
| Download fails | Check Artifactory URL and token permissions |
| Filename mismatch in URL | Verify with validation script above |
| Merge conflicts in `index.json` | Keep HEAD changes: `git checkout --ours index.json` |
