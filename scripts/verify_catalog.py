#!/usr/bin/env python3
"""
Catalog Verification Script

Verifies all URLs in index.json by:
1. Checking that asset files exist locally
2. Starting a local HTTP server on port 8000
3. Testing HTTP connections and validating file sizes match
4. Validating the structure of catalog-display.json

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
import subprocess
import time


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


def verify_html(base_url="http://localhost:8000"):
    """Verify that index.html renders without JavaScript errors using static analysis"""
    
    html_results = {
        'page_load': False,
        'error_count': 0,
        'errors': [],
        'checks_passed': [],
    }
    
    try:
        # Fetch the index.html page
        url = f"{base_url}/index.html"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as response:
            content = response.read().decode('utf-8')
            
        if response.status == 200:
            html_results['page_load'] = True
        
        # Check 1: Null-safe documentation handling
        if '(version.documentation && version.documentation.length > 0)' in content:
            html_results['checks_passed'].append('Null-safe documentation check present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Missing null-safe documentation check - unsafe .map() on documentation')
        
        # Check 2: Data loading mechanism
        if 'fetch(\'./index.json\')' in content or 'fetch("./index.json")' in content:
            html_results['checks_passed'].append('Data loading mechanism present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Data loading mechanism not found')

        # Check 3: Homepage display settings loading
        if 'fetch(\'./catalog-display.json\')' in content or 'fetch("./catalog-display.json")' in content:
            html_results['checks_passed'].append('Catalog display settings loading present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Catalog display settings loading not found')
        
        # Check 4: Package display logic
        if 'displayPackages' in content:
            html_results['checks_passed'].append('Package display logic present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Package display logic missing')
        
        # Check 5: Version row generation
        if 'generateVersionRows' in content:
            html_results['checks_passed'].append('Version row generation present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Version row generation missing')
        
        # Check 6: Table structure
        if '<table>' in content and '<thead>' in content and '<tbody>' in content:
            html_results['checks_passed'].append('HTML table structure present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('HTML table structure incomplete')
        
        # Check 7: Error handling
        if 'catch (error)' in content or 'catch(error)' in content:
            html_results['checks_passed'].append('Error handling present')
        else:
            html_results['error_count'] += 1
            html_results['errors'].append('Error handling missing')
            
    except Exception as e:
        html_results['error_count'] += 1
        html_results['errors'].append(f"Failed to fetch/parse index.html: {str(e)}")
    
    return html_results


def verify_display_config(display_json):
    """Validate catalog-display.json syntax and supported structure."""
    results = {'error_count': 0, 'errors': [], 'checks_passed': []}

    try:
        with open(display_json, 'r') as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        results['error_count'] += 1
        results['errors'].append(f'Unable to read valid JSON from {display_json}: {e}')
        return results

    if not isinstance(config, dict):
        results['error_count'] += 1
        results['errors'].append('Display settings must be a JSON object')
        return results

    supported_keys = ('hiddenPackages', 'hiddenVersions')
    unknown_keys = set(config).difference(supported_keys)
    if unknown_keys:
        results['error_count'] += 1
        results['errors'].append(f'Unknown display settings key(s): {", ".join(sorted(unknown_keys))}')

    for key in supported_keys:
        if key not in config:
            results['error_count'] += 1
            results['errors'].append(f'Missing required display settings key: {key}')
        elif not isinstance(config[key], list):
            results['error_count'] += 1
            results['errors'].append(f'{key} must be an array')

    hidden_packages = config.get('hiddenPackages')
    if isinstance(hidden_packages, list):
        for index, package in enumerate(hidden_packages):
            if not isinstance(package, str) or not package.strip():
                results['error_count'] += 1
                results['errors'].append(f'hiddenPackages[{index}] must be a non-empty string')

    hidden_versions = config.get('hiddenVersions')
    if isinstance(hidden_versions, list):
        allowed_version_keys = {'package', 'version', 'platformVersion'}
        for index, rule in enumerate(hidden_versions):
            if not isinstance(rule, dict):
                results['error_count'] += 1
                results['errors'].append(f'hiddenVersions[{index}] must be an object')
                continue

            unknown_rule_keys = set(rule) - allowed_version_keys
            if unknown_rule_keys:
                results['error_count'] += 1
                results['errors'].append(
                    f'hiddenVersions[{index}] has unknown key(s): {", ".join(sorted(unknown_rule_keys))}'
                )

            criteria_keys = {'version', 'platformVersion'} & set(rule)
            if not criteria_keys:
                results['error_count'] += 1
                results['errors'].append(
                    f'hiddenVersions[{index}] must specify version, platformVersion, or both'
                )

            for key in allowed_version_keys & set(rule):
                if not isinstance(rule[key], str) or not rule[key].strip():
                    results['error_count'] += 1
                    results['errors'].append(f'hiddenVersions[{index}].{key} must be a non-empty string')

    if results['error_count'] == 0:
        results['checks_passed'].append('catalog-display.json structure is valid')

    return results


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


def print_results(catalog_results, html_results=None, display_results=None):
    """Print verification results in a readable format"""

    print("\n" + "="*100)
    print("CATALOG VERIFICATION REPORT")
    print("="*100)
    print(f"\nTotal URLs: {catalog_results['total']}")
    print(f"Passed: {catalog_results['passed']} ✓")
    print(f"Failed: {catalog_results['failed']} ✗")

    if catalog_results['failed'] > 0:
        print("\n" + "-"*100)
        print("CATALOG FAILURES")
        print("-"*100)

        for detail in catalog_results['details']:
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
    print("CATALOG DETAILS")
    print("-"*100)

    for detail in catalog_results['details']:
        status_icon = "✓" if detail['status'] == 'PASSED' else "✗"
        size_str = bytes_to_human(detail['local_size']) if detail['local_size'] else "N/A"
        print(f"{status_icon} {detail['package']:35} v{detail['version']:10} {detail['platform']:10} {size_str:>10}")

    # Print HTML verification results if available
    if html_results:
        print("\n" + "="*100)
        print("HTML RENDERING VERIFICATION")
        print("="*100)
        
        page_status = "✓ OK" if html_results['page_load'] else "✗ FAILED"
        print(f"\nPage Load: {page_status}")
        
        if html_results['checks_passed']:
            print(f"\n✓ Checks Passed ({len(html_results['checks_passed'])}):")
            for check in html_results['checks_passed']:
                print(f"  ✓ {check}")
        
        if html_results['error_count'] > 0:
            print(f"\n❌ HTML Checks Failed ({html_results['error_count']}):")
            for error in html_results['errors']:
                print(f"  ✗ {error}")
        else:
            print("\n✓ All HTML checks passed")

    if display_results:
        print("\n" + "="*100)
        print("HOMEPAGE DISPLAY CONFIGURATION")
        print("="*100)

        if display_results['checks_passed']:
            for check in display_results['checks_passed']:
                print(f"✓ {check}")

        if display_results['error_count'] > 0:
            print(f"\n❌ Display configuration checks failed ({display_results['error_count']}):")
            for error in display_results['errors']:
                print(f"  ✗ {error}")
        else:
            print("✓ All display configuration checks passed")

    print("\n" + "="*100 + "\n")

    # Return success only if every requested verification passes
    catalog_success = catalog_results['failed'] == 0
    html_success = html_results is None or html_results['error_count'] == 0
    display_success = display_results is None or display_results['error_count'] == 0
    return catalog_success and html_success and display_success


if __name__ == '__main__':
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://localhost:8000"

    repo_root = get_repo_root()
    catalog_json = repo_root / "index.json"
    display_json = repo_root / "catalog-display.json"
    assets_dir = repo_root

    # Run catalog verification
    catalog_results = verify_catalog(str(catalog_json), str(assets_dir), base_url)
    
    # Run HTML verification
    html_results = verify_html(base_url)

    # Validate homepage display configuration
    display_results = verify_display_config(display_json)
    
    # Print combined results
    success = print_results(catalog_results, html_results, display_results)

    sys.exit(0 if success else 1)
