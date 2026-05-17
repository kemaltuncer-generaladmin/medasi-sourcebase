# 🚀 Coolify Deployment Rehberi - SourceBase (kaynakmerkezi)

**Proje**: SourceBase (kaynakmerkezi)  
**Platform**: Coolify  
**Tarih**: 2026-05-16  
**Durum**: Production Ready ✅

---

## 📋 Ön Gereksinimler

### 1. Coolify Kurulumu
- ✅ Coolify sunucusu çalışır durumda
- ✅ Domain yapılandırması hazır: `sourcebase.medasi.com.tr`
- ✅ SSL sertifikası otomatik (Let's Encrypt)

### 2. Supabase Hazırlığı
- ✅ Supabase projesi aktif: `https://medasi.com.tr`
- ✅ Database migrations uygulandı
- ✅ Edge Functions deploy edildi
- ✅ Anon key ve Service Role key hazır

### 3. Git Repository
- ✅ Kod GitHub/GitLab'da
- ✅ `main` branch production-ready
- ✅ Dockerfile ve nginx.conf mevcut

---

## 🔧 Coolify'da Proje Oluşturma

### Adım 1: Yeni Proje Ekle

1. Coolify Dashboard'a giriş yap
2. **+ New Resource** > **Application** seç
3. **Git Repository** seç
4. Repository bilgilerini gir:
   - **Repository URL**: `https://github.com/your-org/sourcebase.git`
   - **Branch**: `main`
   - **Build Pack**: `Dockerfile`

### Adım 2: Temel Ayarlar

**General Settings:**
- **Name**: `sourcebase` veya `kaynakmerkezi`
- **Description**: `SourceBase - MedAsi Kaynak Merkezi`
- **Port**: `80` (Nginx default port)
- **Health Check Path**: `/` (nginx health check)

**Domain Settings:**
- **Domain**: `sourcebase.medasi.com.tr`
- **SSL**: ✅ Enable (Let's Encrypt otomatik)
- **Force HTTPS**: ✅ Enable

---

## 🔐 Environment Variables (Build Args)

Coolify'da **Build Args** sekmesine aşağıdaki değişkenleri ekle:

### ⚠️ ÖNEMLİ: Build Args (Docker Build-Time)

Bu değişkenler **Docker build sırasında** Flutter uygulamasına gömülür. Public bilgiler olmalı!

```bash
# Supabase Public Configuration
SOURCEBASE_SUPABASE_URL=https://medasi.com.tr
SOURCEBASE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SOURCEBASE_PUBLIC_URL=https://sourcebase.medasi.com.tr
```

### 📝 Değişken Açıklamaları

| Variable | Açıklama | Örnek Değer |
|----------|----------|-------------|
| `SOURCEBASE_SUPABASE_URL` | Supabase project URL | `https://medasi.com.tr` |
| `SOURCEBASE_SUPABASE_ANON_KEY` | Supabase public anon key (güvenli) | `eyJhbGc...` |
| `SOURCEBASE_PUBLIC_URL` | SourceBase production URL | `https://sourcebase.medasi.com.tr` |

### 🔑 Supabase Keys Nasıl Bulunur?

1. Supabase Dashboard'a git: `https://supabase.com/dashboard`
2. Projeyi seç
3. **Settings** > **API** sekmesine git
4. **Project URL**: `SOURCEBASE_SUPABASE_URL` için kullan
5. **anon public**: `SOURCEBASE_SUPABASE_ANON_KEY` için kullan

---

## 🏗️ Build Ayarları

### Dockerfile Kontrolü

Coolify otomatik olarak root dizindeki `Dockerfile`'ı kullanır:

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG SOURCEBASE_SUPABASE_URL=""
ARG SOURCEBASE_SUPABASE_ANON_KEY=""
ARG SOURCEBASE_PUBLIC_URL=""
RUN flutter build web --release \
  --dart-define=SOURCEBASE_SUPABASE_URL="${SOURCEBASE_SUPABASE_URL}" \
  --dart-define=SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_ANON_KEY}" \
  --dart-define=SOURCEBASE_PUBLIC_URL="${SOURCEBASE_PUBLIC_URL}"

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
RUN chmod -R a+rX /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
```

### Build Süresi

- **İlk build**: ~5-8 dakika (Flutter dependencies download)
- **Sonraki buildler**: ~3-5 dakika (cache sayesinde)

---

## 🚀 Deployment Adımları

### Manuel Deployment

1. Coolify Dashboard'da projeyi aç
2. **Deploy** butonuna tıkla
3. Build loglarını izle
4. Deployment tamamlandığında `https://sourcebase.medasi.com.tr` adresini kontrol et

### Otomatik Deployment (Git Push)

Coolify'da **Auto Deploy** özelliğini aktif et:

1. **Settings** > **Source** sekmesine git
2. **Auto Deploy** toggle'ını aç
3. **Webhook URL**'yi kopyala
4. GitHub/GitLab'da webhook olarak ekle

Artık her `git push` otomatik deployment tetikler!

### CLI ile Deployment (deploy.sh)

```bash
# .env dosyasını oluştur
cp .env.example .env

# Webhook URL'yi .env'ye ekle
echo 'SOURCEBASE_DEPLOY_WEBHOOK=https://coolify.example.com/api/v1/deploy?uuid=xxx' >> .env

# Deploy et
./deploy.sh
```

---

## ✅ Deployment Doğrulama

### 1. Health Check

```bash
curl -I https://sourcebase.medasi.com.tr
```

Beklenen response:
```
HTTP/2 200
content-type: text/html
```

### 2. Frontend Test

Tarayıcıda aç: `https://sourcebase.medasi.com.tr`

Kontrol listesi:
- [ ] Sayfa yükleniyor
- [ ] Login ekranı görünüyor
- [ ] Console'da hata yok
- [ ] Network tab'da 200 OK responses

### 3. Auth Test

1. Login ekranına git
2. Test kullanıcısı ile giriş yap
3. Dashboard yüklenmeli
4. Supabase bağlantısı çalışmalı

### 4. Cache Test

```bash
# Cache headers kontrolü
curl -I https://sourcebase.medasi.com.tr/main.dart.js
```

Beklenen:
```
Cache-Control: no-store, no-cache, must-revalidate, max-age=0
```

---

## 🐛 Sorun Giderme

### Build Hatası: "Flutter command not found"

**Çözüm**: Dockerfile'da doğru Flutter image kullanıldığından emin ol:
```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build
```

### Build Hatası: "pub get failed"

**Çözüm**: `pubspec.yaml` ve `pubspec.lock` dosyalarının güncel olduğundan emin ol:
```bash
# Local'de test et
flutter pub get
flutter pub upgrade
git add pubspec.lock
git commit -m "Update dependencies"
git push
```

### Runtime Hatası: "Supabase URL is empty"

**Çözüm**: Build Args'ın doğru tanımlandığından emin ol:
1. Coolify Dashboard > SourceBase > **Build Args**
2. `SOURCEBASE_SUPABASE_URL` ve `SOURCEBASE_SUPABASE_ANON_KEY` değerlerini kontrol et
3. Rebuild et

### 404 Hatası: SPA Routing Çalışmıyor

**Çözüm**: `nginx.conf` dosyasının doğru olduğundan emin ol:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### SSL Sertifika Hatası

**Çözüm**: Coolify'da SSL ayarlarını kontrol et:
1. **Settings** > **Domains**
2. **Force HTTPS**: ✅
3. **Let's Encrypt**: ✅
4. **Renew Certificate** butonuna tıkla

---

## 📊 Monitoring ve Logs

### Build Logs

Coolify Dashboard'da:
1. Projeyi aç
2. **Deployments** sekmesine git
3. Son deployment'ı seç
4. **Build Logs** görüntüle

### Runtime Logs

```bash
# Coolify Dashboard'da
Logs sekmesi > Real-time logs
```

### Nginx Access Logs

```bash
# Container içinde
docker exec -it <container-id> tail -f /var/log/nginx/access.log
```

---

## 🔄 Rollback

### Son Deployment'a Geri Dön

1. Coolify Dashboard > SourceBase
2. **Deployments** sekmesi
3. Önceki başarılı deployment'ı seç
4. **Redeploy** butonuna tıkla

### Git Commit'e Geri Dön

```bash
# Local'de
git revert HEAD
git push origin main

# Coolify otomatik deploy edecek
```

---

## 🎯 Production Checklist

### Pre-Deployment
- [x] Dockerfile environment variable isimleri düzeltildi
- [x] nginx.conf SPA routing yapılandırıldı
- [x] Health check endpoint eklendi
- [x] Cache headers yapılandırıldı
- [x] .dockerignore optimize edildi

### Deployment
- [ ] Coolify'da proje oluşturuldu
- [ ] Build Args tanımlandı
- [ ] Domain yapılandırıldı
- [ ] SSL aktif edildi
- [ ] İlk deployment başarılı

### Post-Deployment
- [ ] Health check başarılı
- [ ] Frontend yükleniyor
- [ ] Auth çalışıyor
- [ ] Supabase bağlantısı OK
- [ ] Cache headers doğru
- [ ] Logs temiz

---

## 📞 Destek ve Kaynaklar

### Dokümantasyon
- [PRODUCTION_READY.md](./PRODUCTION_READY.md) - Detaylı production rehberi
- [Dockerfile](./Dockerfile) - Build konfigürasyonu
- [nginx.conf](./nginx.conf) - Web server ayarları
- [deploy.sh](./deploy.sh) - Deployment script

### Coolify Kaynakları
- [Coolify Docs](https://coolify.io/docs)
- [Dockerfile Deployment](https://coolify.io/docs/knowledge-base/docker/dockerfile)
- [Environment Variables](https://coolify.io/docs/knowledge-base/environment-variables)

### Flutter Web Kaynakları
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Flutter Docker](https://docs.flutter.dev/deployment/docker)

---

## 🎉 Başarılı Deployment!

Tüm adımlar tamamlandıysa, SourceBase artık production'da çalışıyor!

**Canlı URL**: https://sourcebase.medasi.com.tr

### Sonraki Adımlar

1. **Monitoring**: Uptime monitoring ekle (UptimeRobot, Pingdom)
2. **Analytics**: Google Analytics veya Plausible entegre et
3. **Error Tracking**: Sentry veya Rollbar ekle
4. **Performance**: Lighthouse audit çalıştır
5. **Backup**: Otomatik backup stratejisi oluştur

---

**Son Güncelleme**: 2026-05-16  
**Versiyon**: 1.0.0  
**Durum**: ✅ Production Ready
