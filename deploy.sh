#!/bin/bash

# SourceBase Coolify Deployment Script
# This script triggers deployment for SourceBase application only

set -e

echo "🚀 Starting SourceBase deployment..."

# SourceBase Coolify App UUID (from AGENTS.md)
SOURCEBASE_APP_UUID="h3qdzmbjy6lofttbejgx666a"
COOLIFY_API_KEY="Qvn8bAtyTsVFO8cijFp5nFw4igpLSNBIbuIrUDrhd9409b34"
COOLIFY_URL="http://46.225.100.139:8000"

echo "📦 App UUID: $SOURCEBASE_APP_UUID"
echo "🌐 Coolify URL: $COOLIFY_URL"

# Trigger deployment
echo "🔄 Triggering Coolify deployment..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  "${COOLIFY_URL}/api/v1/deploy?uuid=${SOURCEBASE_APP_UUID}&force=false" \
  -H "Authorization: Bearer ${COOLIFY_API_KEY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "📊 HTTP Status: $HTTP_CODE"
echo "📄 Response: $BODY"

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  echo "✅ Deployment triggered successfully!"
  echo "🔗 Check status at: https://sourcebase.medasi.com.tr"
  exit 0
else
  echo "❌ Deployment failed with status $HTTP_CODE"
  exit 1
fi
