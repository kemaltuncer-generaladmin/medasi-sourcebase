#!/bin/bash

# SourceBase Local Docker Build Test Script
# Bu script local'de Docker build test eder

set -e

echo "🧪 SourceBase Docker Build Test Başlatılıyor..."
echo ""

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test build args
TEST_SUPABASE_URL="https://medasi.com.tr"
TEST_SUPABASE_ANON_KEY="test-anon-key-will-be-replaced"
TEST_PUBLIC_URL="http://localhost:8088"

echo "📋 Build Parametreleri:"
echo "  - SOURCEBASE_SUPABASE_URL: ${TEST_SUPABASE_URL}"
echo "  - SOURCEBASE_SUPABASE_ANON_KEY: ${TEST_SUPABASE_ANON_KEY:0:20}..."
echo "  - SOURCEBASE_PUBLIC_URL: ${TEST_PUBLIC_URL}"
echo ""

# Docker build komutu
echo "🔨 Docker build başlatılıyor..."
echo ""

docker build \
  --build-arg SOURCEBASE_SUPABASE_URL="${TEST_SUPABASE_URL}" \
  --build-arg SOURCEBASE_SUPABASE_ANON_KEY="${TEST_SUPABASE_ANON_KEY}" \
  --build-arg SOURCEBASE_PUBLIC_URL="${TEST_PUBLIC_URL}" \
  -t sourcebase:test \
  -f Dockerfile \
  .

BUILD_EXIT_CODE=$?

echo ""
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Build başarılı!${NC}"
    echo ""
    echo "📦 Image oluşturuldu: sourcebase:test"
    echo ""
    echo "🚀 Test etmek için:"
    echo "   docker run -d -p 8088:80 --name sourcebase-test sourcebase:test"
    echo "   open http://localhost:8088"
    echo ""
    echo "🧹 Temizlemek için:"
    echo "   docker stop sourcebase-test"
    echo "   docker rm sourcebase-test"
    echo "   docker rmi sourcebase:test"
else
    echo -e "${RED}❌ Build başarısız! Exit code: ${BUILD_EXIT_CODE}${NC}"
    echo ""
    echo "🔍 Sorun giderme:"
    echo "  1. Dockerfile'ı kontrol et"
    echo "  2. pubspec.yaml bağımlılıklarını kontrol et"
    echo "  3. Build loglarını incele"
    exit 1
fi
