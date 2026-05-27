#!/usr/bin/env python3
"""
Catalog Verification Script

Verifies all URLs in index.json by:
1. Checking that asset files exist locally
2. Starting a local HTTP server on port 8000
3. Testing HTTP connections and validating file sizes match

Usage:
    python3 scripts/verify_catalog.py [base_url]

Examples:
    python3 scripts/verify_catalog.py                    # Uses http://localhost:8000
    python3 scripts/verify_catalog.py http://localhost:9000
"""

import json
import os
import urllib.request
import urllib.error
from urllib.parse import urlparse
import sys
from pathlib import Path


def bytes_to_human(size_bytes):
    """Convert bytes to human-readable format"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f}{unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f}TB"


def get_local_file_size(file_path):
    """Get the size of a local file"""
    try:
        return os.path.getsize(file_path)
    except FileNotFoundError:
        return None


def get_remote_file_size(url):
    """Get the size of a remote file via HEAD request"""
    try:
        req = urllib.request.Request(url, method='HEAD')
        with urllib.request.urlopen(req, timeout=5) as response:
            size = int(response.headers.get('content-length', 0))
            return (response.status, size)
    except urllib.error.HTTPError as e:
        return (e.code, None)
    except Exception as e:
        return (None, None)


def get_repo_root():
    """Get the repository root directory"""
    script_dir = Path(__file__).parent
    return script_dir.parent


def verify_catalog(catalog_json, assets_dir, base_url="http://localhost:8000"):
    """Verify all URLs in catalog return assets with correct sizes"""

    with open(catalog_json, 'r') as f:
        data = json.load(f)

    results = {
        'total': 0,
        'passed': 0,
        'failed': 0,
        'details': []
    }

    for package in data['packages']:
        package_name = package['package']

        for version_info in package['versions']:
            platform_version = version_info['platformVersion']
            component_version = version_info['latestVersion']

            for binary in version_info.get('binaries', []):
                results['total'] += 1
                original_url = binary['url']

                # Extract path from original URL: /pega-dev-components/assets/...
                parsed = urlparse(original_url)
                local_path = parsed.path

                # Remove query string
                local_path = local_path.split('?')[0]

                # For localhost: convert /pega-dev-components/assets/... to /assets/...
                if local_path.startswith('/pega-dev-components'):
                    localhost_path = local_path[len('/pega-dev-components'):]
                else:
                    localhost_path = local_path

                localhost_url = f"{base_url}{localhost_path}"

                # For the file path, strip the /pega-dev-components prefix
                if local_path.startswith('/pega-dev-components/'):
                    relative_path = local_path[len('/pega-dev-components/'):]
                else:
                    relative_path = local_path.lstrip('/')

                file_path = os.path.join(assets_dir, relative_path)

                detail = {
                    'package': package_name,
                    'platform': platform_version,
                    'version': component_version,
                    'binary': binary['name'],
                    'url': localhost_url,
                    'file_path': file_path,
                    'status': 'UNKNOWN',
                    'local_size': None,
                    'remote_size': None,
                    'error': None
                }

                # Check if local file exists and get its size
                local_size = get_local_file_size(file_path)

                if local_size is None:
                    detail['status'] = 'FAILED'
                    detail['error'] = 'File not found locally'
                    results['failed'] += 1
                else:
                    detail['local_size'] = local_size

                    # Try to access the URL
                    status_code, remote_size = get_remote_file_size(localhost_url)

                    if status_code == 200:
                        detail['remote_size'] = remote_size

                        if remote_size == local_size:
                            detail['status'] = 'PASSED'
                            results['passed'] += 1
                        else:
                            detail['status'] = 'FAILED'
                            detail['error'] = f'Size mismatch: local={local_size}, remote={remote_size}'
                            results['failed'] += 1
                    else:
                        detail['status'] = 'FAILED'
                        detail['error'] = f'HTTP {status_code}' if status_code else 'Connection failed'
                        results['failed'] += 1

                results['details'].append(detail)

    return results


def print_results(results):
    """Print verification results in a readable format"""

    print("\n" + "="*100)
    print("CATALOG VERIFICATION REPORT")
    print("="*100)
    print(f"\nTotal URLs: {results['total']}")
    print(f"Passed: {results['passed']} ✓")
    print(f"Failed: {results['failed']} ✗")

    if results['failed'] > 0:
        print("\n" + "-"*100)
        print("FAILURES")
        print("-"*100)

        for detail in results['details']:
            if detail['status'] != 'PASSED':
                print(f"\n❌ {detail['package']} v{detail['version']} (Platform {detail['platform']})")
                print(f"   URL: {detail['url']}")
                print(f"   File: {detail['file_path']}")
                if detail['local_size']:
                    print(f"   Local Size: {bytes_to_human(detail['local_size'])}")
                if detail['remote_size']:
                    print(f"   Remote Size: {bytes_to_human(detail['remote_size'])}")
                if detail['error']:
                    print(f"   Error: {detail['error']}")

    print("\n" + "-"*100)
    print("DETAILS")
    print("-"*100)

    for detail in results['details']:
        status_icon = "✓" if detail['status'] == 'PASSED' else "✗"
        size_str = bytes_to_human(detail['local_size']) if detail['local_size'] else "N/A"
        print(f"{status_icon} {detail['package']:35} v{detail['version']:10} {detail['platform']:10} {size_str:>10}")

    print("\n" + "="*100 + "\n")

    return results['failed'] == 0


if __name__ == '__main__':
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://localhost:8000"

    repo_root = get_repo_root()
    catalog_json = repo_root / "index.json"
    assets_dir = repo_root

    results = verify_catalog(str(catalog_json), str(assets_dir), base_url)
    success = print_results(results)

    sys.exit(0 if success else 1)
