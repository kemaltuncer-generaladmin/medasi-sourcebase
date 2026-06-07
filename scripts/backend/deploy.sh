#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

if [ -z "${SOURCEBASE_DEPLOY_WEBHOOK:-}" ]; then
  echo "SOURCEBASE_DEPLOY_WEBHOOK is not set in $ENV_FILE"
  exit 1
fi

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

echo "Triggering SourceBase Coolify deployment..."
http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X POST "$SOURCEBASE_DEPLOY_WEBHOOK")"
response="$(cat "$response_file")"

if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
  echo "Deployment trigger failed with HTTP $http_code"
  echo "$response" | jq '{message, error, status, deployment_uuid}' 2>/dev/null || echo "$response"
  exit 1
fi

if echo "$response" | grep -qi 'Unauthenticated'; then
  echo "Deployment trigger failed: webhook authentication was rejected."
  exit 1
fi

deployment_uuid="$(echo "$response" | jq -r '.deployment_uuid // empty' 2>/dev/null || true)"
echo "Deployment triggered for https://sourcebase.medasi.com.tr"

if [ -n "$deployment_uuid" ]; then
  echo "Deployment UUID: $deployment_uuid"
  echo "Check status: $SCRIPT_DIR/check_deployment.py"
else
  echo "Coolify did not return a deployment UUID; check status manually."
fi
