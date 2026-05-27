---
name: verify-catalog
description: Verify all catalog URLs return assets with matching file sizes. Use when user asks to "verify catalog", "validate urls", "check assets", or "verify releases".
metadata:
  audience: personal
  workflow: verification
tools:
  - bash
  - read
---

# Catalog Verification Skill

Verify that all URLs in the Pega Dev Components catalog (`index.json`) are valid and asset files match expected sizes.

## Overview

The verification process:
1. **Parses** the catalog (`index.json`) to extract all binary URLs
2. **Starts** a local HTTP server on port 8000
3. **Tests** each URL with HTTP HEAD requests
4. **Validates** that content-length matches actual local file sizes
5. **Reports** pass/fail status for all components and versions

## Prerequisites

- Working directory: `pega-dev-components` repo
- Python 3.6+
- All assets present in `assets/components/` directory
- Port 8000 available (or specify alternate port)

## Workflows

### Verify All Catalog URLs

Trigger: "verify catalog", "validate urls", "check assets", "verify catalog integrity"

```bash
# Start HTTP server in background
cd /home/sartm/code/component-catalog/pega-dev-components
python3 -m http.server 8000 &
SERVER_PID=$!

# Run verification
python3 scripts/verify_catalog.py http://localhost:8000

# Kill server when done
kill $SERVER_PID
```

**What happens:**
- Reads `index.json` and extracts all binary entries
- Converts GitHub Pages URLs (`https://pegasystems.github.io/pega-dev-components/assets/...`) to localhost URLs (`http://localhost:8000/assets/...`)
- For each URL:
  1. Checks if local file exists
  2. Sends HEAD request and verifies HTTP 200 response
  3. Compares `content-length` header with actual file size
  4. Reports PASS if all checks succeed, FAIL otherwise
- Generates summary table and details report
- Returns exit code 0 if all pass, 1 if any fail

### Verify with Custom Port

```bash
python3 scripts/verify_catalog.py http://localhost:9000
```

### Quick Verification (Check Local Files Only)

To verify without starting a server:

```bash
# Just check that all files referenced in index.json exist locally
python3 -c "
import json
from pathlib import Path

with open('index.json') as f:
    data = json.load(f)

missing = []
for pkg in data['packages']:
    for v in pkg['versions']:
        for b in v.get('binaries', []):
            url = b['url']
            path = url.split('/pega-dev-components/')[-1]
            if not Path(path).exists():
                missing.append(path)

if missing:
    print('Missing files:')
    for m in missing:
        print(f'  - {m}')
else:
    print('✓ All files exist locally')
"
```

## Verification Script Details

**Location:** `scripts/verify_catalog.py`

**Features:**
- Pure Python (no external dependencies)
- Uses standard library `urllib` for HTTP requests
- Converts GitHub Pages paths to localhost paths automatically
- Reports file sizes in human-readable format (B, KB, MB, GB)
- Color-coded output: ✓ for pass, ✗ for fail
- Detailed failure reporting with specific errors

**Exit Codes:**
- `0` – All URLs verified successfully
- `1` – One or more URLs failed verification

## URL Path Conversion

The script automatically converts deployment URLs to localhost:

| Format | Example |
|--------|---------|
| **Production** | `https://pegasystems.github.io/pega-dev-components/assets/components/platform-blueprint-component/0.2.13/blueprint-0.2.13-bundle.jar` |
| **Local** | `http://localhost:8000/assets/components/platform-blueprint-component/0.2.13/blueprint-0.2.13-bundle.jar` |

The `/pega-dev-components/` segment is removed because the HTTP server serves from the repo root.

## Supported Components

Verification covers all components in `index.json`:

- **Platform Blueprint Component** (multiple versions across platforms 23.1.0–26.1.0)
- **AI Authoring Rules** (multiple versions across platforms 24.1.0–26.1.0)
- **CDH Blueprint Import Module** (version 0.0.1 for platform 26.1.0)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Connection refused` | HTTP server not running on specified port |
| `File not found locally` | Asset file missing from `assets/` directory |
| `Size mismatch` | File was corrupted or incomplete during download |
| `HTTP 404` | URL path doesn't match actual file structure |
| `Port already in use` | Kill existing process: `lsof -ti:8000 \| xargs kill -9` |

## Integration with Release Process

The verification script is ideal for:
- **Post-release validation** – Confirm all new URLs work after publishing
- **Pre-deployment testing** – Validate catalog before merging to main
- **Asset integrity checks** – Ensure files weren't corrupted during transfer
- **CI/CD pipelines** – Automated quality gates for releases

## Base directory

This skill operates in the `pega-dev-components` repo.

Relative paths (e.g., `scripts/verify_catalog.py`) are relative to the repo root.
