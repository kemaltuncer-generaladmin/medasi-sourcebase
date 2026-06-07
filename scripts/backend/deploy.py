#!/usr/bin/env python3
"""Trigger the SourceBase Coolify deployment without printing secrets."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
ENV_FILE = REPO_ROOT / ".env"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def compact_response(body: str) -> str:
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return body[:500]
    safe = {
        key: data.get(key)
        for key in ("message", "status", "deployment_uuid", "uuid")
        if key in data
    }
    return json.dumps(safe or {"ok": True}, indent=2)


def trigger_deployment() -> int:
    load_env_file(ENV_FILE)

    app_uuid = os.environ.get("SOURCEBASE_COOLIFY_APP_UUID", "h3qdzmbjy6lofttbejgx666a")
    api_key = os.environ.get("SOURCEBASE_COOLIFY_API_KEY")
    coolify_url = os.environ.get("SOURCEBASE_COOLIFY_URL", "http://46.225.100.139:8000")

    if not api_key:
        print(f"SOURCEBASE_COOLIFY_API_KEY is not set in {ENV_FILE}")
        return 1

    url = f"{coolify_url.rstrip('/')}/api/v1/deploy?uuid={app_uuid}&force=false"
    print("Triggering SourceBase Coolify deployment...")
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
        print(f"Deployment trigger failed: {error}")
        return 1

    if result.stderr.strip():
        print(result.stderr.strip())
    body, _, status_text = result.stdout.rpartition("\n")
    status = int(status_text) if status_text.isdigit() else 0
    print(f"HTTP Status: {status}")
    print(compact_response(body))
    return 0 if status in (200, 201) else 1


if __name__ == "__main__":
    sys.exit(trigger_deployment())
