# SourceBase Deployment Notları

**Tarih:** 17 Mayıs 2026  
**Uygulama:** SourceBase (kaynakmerkezi)

---

## Yerel Geliştirme

```bash
# Flutter SDK PATH
export PATH="/Volumes/driveand/Developer/flutter/bin:$PATH"

# Bağımlılıkları yükle
flutter pub get

# Analiz
flutter analyze

# Test
flutter test

# Web build
flutter build web --release

# iOS build (macOS, Xcode ile)
flutter build ios --no-codesign

# Android build
flutter build apk --release
```

---

## Docker Build

```bash
# Docker build (test build arg'ları ile)
docker build \
  --build-arg SOURCEBASE_SUPABASE_URL="https://medasi.com.tr" \
  --build-arg SOURCEBASE_SUPABASE_ANON_KEY="<anon-key>" \
  --build-arg SOURCEBASE_PUBLIC_URL="https://sourcebase.medasi.com.tr" \
  -t sourcebase:test \
  .

# Lokalde test
docker run -d -p 8088:80 --name sourcebase-test sourcebase:test
open http://localhost:8088

# Temizle
docker stop sourcebase-test && docker rm sourcebase-test
```

---

## Coolify Deployment

### Otomatik (git push)
```bash
git add .
git commit -m "Production deployment"
git push origin git-docker-coolify
```

### Manuel (script ile)
```bash
export SOURCEBASE_COOLIFY_API_KEY="<coolify-api-key>"
python3 deploy.py
```

### Deployment Durumu Kontrol
```bash
export SOURCEBASE_COOLIFY_API_KEY="<coolify-api-key>"
python3 check_deployment.py
```

### Webhook ile
```bash
export SOURCEBASE_COOLIFY_API_KEY="<coolify-api-key>"
export SOURCEBASE_COOLIFY_APP_UUID="h3qdzmbjy6lofttbejgx666a"
./deploy.sh
```

---

## Gerekli Portlar

| Servis | Port | Açıklama |
|--------|------|----------|
| Nginx (SourceBase) | 80 (iç), 443 (dış) | Web uygulaması |
| Supabase | 443 | API ve Auth |
| Coolify | 8000 | Yönetim paneli |

---

## Gerekli Servisler

| Servis | URL | Durum |
|--------|-----|-------|
| Supabase Auth/API | https://medasi.com.tr | ✅ Aktif |
| GCS Storage | sourcebase-sources bucket | ⚠️ CORS bekliyor |
| Vertex AI | Gemini 2.5 Flash | ⚠️ API etkinleştirme bekliyor |
| Coolify | http://46.225.100.139:8000 | ✅ Aktif |

---

## Health Check

```bash
# Ana sayfa
curl -I https://sourcebase.medasi.com.tr

# Beklenen yanıt: HTTP/2 200
```

---

## Migration Komutları

```bash
# Supabase CLI ile
supabase db push

# Veya manuel (SQL Editor üzerinden):
# 1. supabase/migrations/20260515_create_sourcebase_drive_schema.sql
# 2. supabase/migrations/20260516_complete_sourcebase_schema.sql
# 3. supabase/migrations/20260516_fix_generated_jobs_ai_schema.sql
# 4. supabase/migrations/20260516120012_vector_support.sql
# 5. supabase/migrations/20260516120100_create_find_similar_rpc.sql
# 6. supabase/migrations/20260516120448_automate_embedding_triggers.sql
# 7. supabase/migrations/20260516120617_knowledge_graph_schema.sql
# 8. supabase/migrations/20260517_grant_sourcebase_rest_access.sql (YENİ)
# 9. supabase/migrations/20260517_create_sourcebase_storage_roots.sql (YENİ)
```

---

## Edge Function Deploy

```bash
# Secret'ları ayarla
./scripts/configure_sourcebase_supabase.sh

# Deploy et
supabase functions deploy sourcebase
```

---

## Rollback

### Coolify üzerinden
1. Dashboard → SourceBase → Deployments
2. Önceki başarılı deployment'ı seç
3. "Redeploy" butonuna tıkla

### Git üzerinden
```bash
git revert HEAD
git push origin git-docker-coolify
```

### Veritabanı (acil durum)
```sql
-- TÜM SourceBase verilerini siler!
DROP SCHEMA IF EXISTS sourcebase CASCADE;
```

---

## İlk Kurulum Adımları

1. **Supabase projesini hazırla**
   - Migration'ları uygula
   - Edge Function'ı deploy et
   - Auth ayarlarını yapılandır (email template, redirect URL)

2. **GCS bucket'ı yapılandır**
   - Bucket oluştur: `sourcebase-sources`
   - CORS ayarla: `supabase/functions/sourcebase/gcs-cors.json`
   - Service account oluştur ve JSON key'i al

3. **Vertex AI'yı etkinleştir**
   - GCP'de Vertex AI API'yi etkinleştir
   - Service account oluştur (Vertex AI User rolü)
   - JSON key'i al

4. **Coolify'da yapılandır**
   - Build args ekle: SOURCEBASE_SUPABASE_URL, SOURCEBASE_SUPABASE_ANON_KEY, SOURCEBASE_PUBLIC_URL
   - Environment variables ekle: SUPABASE_SERVICE_ROLE_KEY, GCS/Vertex JSON'ları
   - Domain ayarla: sourcebase.medasi.com.tr
   - SSL etkinleştir

5. **Deploy et ve test et**
   - Login/register testi
   - Dosya yükleme testi
   - AI generation testi
