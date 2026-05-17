#!/usr/bin/env python3
"""
SourceBase Coolify Deployment Script
Triggers deployment for SourceBase application only

Required environment variables:
  SOURCEBASE_COOLIFY_API_KEY     Coolify API bearer token
  SOURCEBASE_COOLIFY_APP_UUID    SourceBase application UUID (default: h3qdzmbjy6lofttbejgx666a)
  SOURCEBASE_COOLIFY_URL         Coolify server URL (default: http://46.225.100.139:8000)
"""

import os
import urllib.request
import json
import sys

SOURCEBASE_APP_UUID = os.environ.get("SOURCEBASE_COOLIFY_APP_UUID", "h3qdzmbjy6lofttbejgx666a")
COOLIFY_API_KEY = os.environ.get("SOURCEBASE_COOLIFY_API_KEY")
COOLIFY_URL = os.environ.get("SOURCEBASE_COOLIFY_URL", "http://46.225.100.139:8000")

def trigger_deployment():
    """Trigger Coolify deployment for SourceBase"""

    if not COOLIFY_API_KEY:
        print("❌ SOURCEBASE_COOLIFY_API_KEY environment variable is not set")
        return 1

    print("🚀 Starting SourceBase deployment...")
    print(f"📦 App UUID: {SOURCEBASE_APP_UUID}")
    print(f"🌐 Coolify URL: {COOLIFY_URL}")

    url = f"{COOLIFY_URL}/api/v1/deploy?uuid={SOURCEBASE_APP_UUID}&force=false"

    headers = {
        "Authorization": f"Bearer {COOLIFY_API_KEY}",
        "Accept": "application/json"
    }

    try:
        print("🔄 Triggering Coolify deployment...")

        req = urllib.request.Request(url, headers=headers, method='GET')

        with urllib.request.urlopen(req, timeout=30) as response:
            status_code = response.status
            body = response.read().decode('utf-8')

            print(f"📊 HTTP Status: {status_code}")
            print(f"📄 Response: {body}")

            if status_code in [200, 201]:
                print("✅ Deployment triggered successfully!")
                print("🔗 Check status at: https://sourcebase.medasi.com.tr")
                return 0
            else:
                print(f"❌ Deployment failed with status {status_code}")
                return 1

    except urllib.error.HTTPError as e:
        print(f"❌ HTTP Error: {e.code} - {e.reason}")
        print(f"📄 Response: {e.read().decode('utf-8')}")
        return 1
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(trigger_deployment())
