#!/usr/bin/env python3
"""Check SourceBase Coolify application status without dumping secrets."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
ENV_FILE = REPO_ROOT / ".env"
SECRET_WORDS = ("secret", "token", "key", "password", "authorization", "env")


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def redact(value):
    if isinstance(value, dict):
        return {
            key: "<redacted>" if any(word in key.lower() for word in SECRET_WORDS) else redact(item)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


def check_deployment_status() -> int:
    load_env_file(ENV_FILE)

    app_uuid = os.environ.get("SOURCEBASE_COOLIFY_APP_UUID", "h3qdzmbjy6lofttbejgx666a")
    api_key = os.environ.get("SOURCEBASE_COOLIFY_API_KEY")
    coolify_url = os.environ.get("SOURCEBASE_COOLIFY_URL", "http://46.225.100.139:8000")

    if not api_key:
        print(f"SOURCEBASE_COOLIFY_API_KEY is not set in {ENV_FILE}")
        return 1

    url = f"{coolify_url.rstrip('/')}/api/v1/applications/{app_uuid}"
    print("Checking SourceBase Coolify application status...")
    print(f"App UUID: {app_uuid}")

    command = [
        "curl",
        "-sS",
        "-w",
        "\n%{http_code}",
        "-H",
        f"Authorization: Bearer {api_key}",
        "-H",
        "Accept: application/json",
        "-X",
        "GET",
        url,
    ]

    try:
        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=30)
    except Exception as error:
        print(f"Status check failed: {error}")
        return 1

    if result.stderr.strip():
        print(result.stderr.strip())
    body, _, status_text = result.stdout.rpartition("\n")
    status = int(status_text) if status_text.isdigit() else 0
    print(f"HTTP Status: {status}")
    try:
        data = json.loads(body)
        print(f"Application Status: {data.get('status', 'unknown')}")
        print(f"Domain: {data.get('fqdn', 'https://sourcebase.medasi.com.tr')}")
        print(json.dumps(redact(data), indent=2, sort_keys=True))
    except json.JSONDecodeError:
        print(body[:500])
    return 0 if status == 200 else 1


if __name__ == "__main__":
    sys.exit(check_deployment_status())
