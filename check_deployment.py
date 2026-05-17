#!/usr/bin/env python3
"""
SourceBase Deployment Status Checker
Checks the deployment status on Coolify

Required environment variables:
  SOURCEBASE_COOLIFY_API_KEY     Coolify API bearer token
  SOURCEBASE_COOLIFY_APP_UUID    SourceBase application UUID (default: h3qdzmbjy6lofttbejgx666a)
  SOURCEBASE_COOLIFY_URL         Coolify server URL (default: http://46.225.100.139:8000)
"""

import os
import urllib.request
import json
import sys
import time

SOURCEBASE_APP_UUID = os.environ.get("SOURCEBASE_COOLIFY_APP_UUID", "h3qdzmbjy6lofttbejgx666a")
COOLIFY_API_KEY = os.environ.get("SOURCEBASE_COOLIFY_API_KEY")
COOLIFY_URL = os.environ.get("SOURCEBASE_COOLIFY_URL", "http://46.225.100.139:8000")

def check_deployment_status():
    """Check Coolify deployment status"""

    if not COOLIFY_API_KEY:
        print("❌ SOURCEBASE_COOLIFY_API_KEY environment variable is not set")
        return 1

    print("🔍 Checking SourceBase deployment status...")
    print(f"📦 App UUID: {SOURCEBASE_APP_UUID}")

    url = f"{COOLIFY_URL}/api/v1/applications/{SOURCEBASE_APP_UUID}"

    headers = {
        "Authorization": f"Bearer {COOLIFY_API_KEY}",
        "Accept": "application/json"
    }

    try:
        req = urllib.request.Request(url, headers=headers, method='GET')

        with urllib.request.urlopen(req, timeout=30) as response:
            status_code = response.status
            body = response.read().decode('utf-8')

            if status_code == 200:
                data = json.loads(body)
                print(f"📊 Application Status: {data.get('status', 'unknown')}")
                print(f"🔗 Domain: https://sourcebase.medasi.com.tr")
                print(f"📄 Full Response: {json.dumps(data, indent=2)}")
                return 0
            else:
                print(f"⚠️ Status check returned: {status_code}")
                print(f"📄 Response: {body}")
                return 1

    except urllib.error.HTTPError as e:
        print(f"❌ HTTP Error: {e.code} - {e.reason}")
        try:
            error_body = e.read().decode('utf-8')
            print(f"📄 Error Response: {error_body}")
        except:
            pass
        return 1
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return 1

if __name__ == "__main__":
    print("\n" + "="*60)
    print("SourceBase Deployment Status Check")
    print("="*60 + "\n")

    sys.exit(check_deployment_status())
