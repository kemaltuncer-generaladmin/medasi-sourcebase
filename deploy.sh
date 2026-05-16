#!/bin/bash

# SourceBase Production Deployment Script
# Bu script Coolify deployment'ını tetikler

set -e

echo "🚀 SourceBase Production Deployment Başlatılıyor..."
echo ""

# .env dosyasından değişkenleri yükle
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Gerekli değişkenleri kontrol et
if [ -z "$SOURCEBASE_DEPLOY_WEBHOOK" ]; then
    echo "❌ HATA: SOURCEBASE_DEPLOY_WEBHOOK tanımlı değil"
    echo "Lütfen .env dosyasında SOURCEBASE_DEPLOY_WEBHOOK değişkenini tanımlayın"
    exit 1
fi

echo "📋 Deployment Bilgileri:"
echo "  - Webhook: ${SOURCEBASE_DEPLOY_WEBHOOK:0:50}..."
echo "  - Domain: https://sourcebase.medasi.com.tr"
echo ""

# Deployment'ı tetikle
echo "🔄 Coolify deployment tetikleniyor..."
RESPONSE=$(curl -s -X POST "$SOURCEBASE_DEPLOY_WEBHOOK")

echo ""
echo "✅ Deployment tetiklendi!"
echo ""
echo "📊 Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Deployment UUID'yi çıkar
DEPLOYMENT_UUID=$(echo "$RESPONSE" | jq -r '.deployment_uuid' 2>/dev/null || echo "")

if [ -n "$DEPLOYMENT_UUID" ] && [ "$DEPLOYMENT_UUID" != "null" ]; then
    echo "🆔 Deployment UUID: $DEPLOYMENT_UUID"
    echo ""
    echo "📝 Deployment durumunu kontrol etmek için:"
    echo "   python3 check_deployment.py $DEPLOYMENT_UUID"
else
    echo "⚠️  Deployment UUID alınamadı, manuel kontrol gerekebilir"
fi

echo ""
echo "🌐 Canlı URL: https://sourcebase.medasi.com.tr"
echo ""
echo "⏳ Deployment tamamlanması 2-5 dakika sürebilir"
echo "   Cache temizlemek için tarayıcıda Ctrl+Shift+R (veya Cmd+Shift+R) yapın"
echo ""
echo "✨ Deployment başarıyla tetiklendi!"
