#!/usr/bin/env python3
"""
SourceBase Deployment Status Checker
Checks the deployment status on Coolify
"""

import urllib.request
import json
import sys
import time

# SourceBase Coolify App UUID (from AGENTS.md)
SOURCEBASE_APP_UUID = "h3qdzmbjy6lofttbejgx666a"
DEPLOYMENT_UUID = "k115etvqluyfj89hrwhk91aa"
COOLIFY_API_KEY = "Qvn8bAtyTsVFO8cijFp5nFw4igpLSNBIbuIrUDrhd9409b34"
COOLIFY_URL = "http://46.225.100.139:8000"

def check_deployment_status():
    """Check Coolify deployment status"""
    
    print("🔍 Checking SourceBase deployment status...")
    print(f"📦 App UUID: {SOURCEBASE_APP_UUID}")
    print(f"🆔 Deployment UUID: {DEPLOYMENT_UUID}")
    
    # Check application status
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
