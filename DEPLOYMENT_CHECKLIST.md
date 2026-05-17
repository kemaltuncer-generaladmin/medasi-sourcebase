# ✅ SourceBase Coolify Deployment Checklist

**Proje**: SourceBase (kaynakmerkezi)  
**Tarih**: 2026-05-16  
**Durum**: Ready for Deployment

---

## 🔍 Pre-Deployment Kontroller

### Kod Hazırlığı
- [x] **Dockerfile düzeltildi**: Environment variable isimleri tutarlı (`SOURCEBASE_SUPABASE_ANON_KEY`)
- [x] **nginx.conf hazır**: SPA routing ve cache headers yapılandırıldı
- [x] **.dockerignore optimize**: Gereksiz dosyalar build'e dahil edilmiyor
- [x] **pubspec.yaml güncel**: Tüm bağımlılıklar mevcut
- [x] **Health check eklendi**: Dockerfile'da healthcheck endpoint var

### Supabase Hazırlığı
- [ ] **Database migrations uygulandı**: `supabase/migrations/` klasöründeki SQL'ler çalıştırıldı
- [ ] **Edge Functions deploy edildi**: `supabase functions deploy sourcebase`
- [ ] **Supabase URL hazır**: `https://medasi.com.tr`
- [ ] **Anon Key alındı**: Supabase Dashboard → Settings → API

### Coolify Hazırlığı
- [ ] **Coolify erişimi var**: Dashboard'a giriş yapılabilir
- [ ] **Domain hazır**: `sourcebase.medasi.com.tr` DNS ayarları yapıldı
- [ ] **Git repository erişilebilir**: GitHub/GitLab repo public veya Coolify'a key eklendi

---

## 🚀 Deployment Adımları

### 1. Coolify'da Uygulama Oluştur

```
☐ Coolify Dashboard → + New Resource → Application
☐ Git Repository seç
☐ Repository URL gir
☐ Branch: main
☐ Build Pack: Dockerfile (otomatik algılanır)
☐ Name: sourcebase veya kaynakmerkezi
☐ Port: 80
```

### 2. Domain Yapılandır

```
☐ Settings → Domains
☐ Domain ekle: sourcebase.medasi.com.tr
☐ Force HTTPS: ✅ Enable
☐ Let's Encrypt SSL: ✅ Enable
```

### 3. Build Args Ekle

```
☐ Settings → Build Args
☐ SOURCEBASE_SUPABASE_URL = https://medasi.com.tr
☐ SOURCEBASE_SUPABASE_ANON_KEY = [Supabase anon key]
☐ SOURCEBASE_PUBLIC_URL = https://sourcebase.medasi.com.tr
☐ Save
```

### 4. İlk Deployment

```
☐ Deploy butonuna tıkla
☐ Build loglarını izle (5-8 dakika)
☐ "Successfully built" mesajını bekle
☐ Container başladığını kontrol et
```

---

## ✅ Post-Deployment Doğrulama

### Health Check

```bash
☐ curl -I https://sourcebase.medasi.com.tr
   Beklenen: HTTP/2 200
```

### Frontend Test

```
☐ Tarayıcıda aç: https://sourcebase.medasi.com.tr
☐ Login ekranı görünüyor
☐ Console'da kritik hata yok
☐ Network tab'da 200 OK responses
☐ Cache-Control headers doğru
```

### Auth Test

```
☐ Login ekranına git
☐ Test kullanıcısı ile giriş yap
☐ Dashboard yükleniyor
☐ Supabase bağlantısı çalışıyor
```

### Performance Test

```
☐ Lighthouse audit çalıştır
☐ Performance score > 80
☐ First Contentful Paint < 2s
☐ Time to Interactive < 3s
```

---

## 🔧 Opsiyonel Ayarlar

### Otomatik Deployment

```
☐ Settings → Source → Auto Deploy: ✅ Enable
☐ Webhook URL'yi kopyala
☐ GitHub/GitLab'da webhook ekle
☐ Test: git push yap, otomatik deploy olmalı
```

### Monitoring

```
☐ Uptime monitoring ekle (UptimeRobot, Pingdom)
☐ Error tracking ekle (Sentry)
☐ Analytics ekle (Google Analytics, Plausible)
```

### Backup

```
☐ Coolify backup ayarlarını kontrol et
☐ Database backup stratejisi oluştur
☐ Disaster recovery planı hazırla
```

---

## 🐛 Sorun Giderme Rehberi

### Build Başarısız

**Kontrol Et:**
1. Build Args doğru tanımlı mı?
2. Dockerfile syntax hatası var mı?
3. pubspec.yaml bağımlılıkları çözülebiliyor mu?
4. Build logs'da spesifik hata mesajı var mı?

**Çözüm:**
```bash
# Local'de test et
./test_build.sh

# Hata varsa düzelt ve push et
git add .
git commit -m "Fix build issue"
git push
```

### Container Başlamıyor

**Kontrol Et:**
1. Port 80 expose edilmiş mi?
2. nginx.conf doğru mu?
3. Health check endpoint çalışıyor mu?

**Çözüm:**
```bash
# Coolify logs kontrol et
Coolify Dashboard → Logs → Real-time logs

# Container içine gir
docker exec -it <container-id> sh
ls -la /usr/share/nginx/html
```

### Domain Erişilemiyor

**Kontrol Et:**
1. DNS ayarları doğru mu? (A record veya CNAME)
2. SSL sertifikası oluşturuldu mu?
3. Firewall kuralları açık mı?

**Çözüm:**
```bash
# DNS kontrol
nslookup sourcebase.medasi.com.tr

# SSL kontrol
curl -vI https://sourcebase.medasi.com.tr

# Coolify'da SSL yenile
Settings → Domains → Renew Certificate
```

### Supabase Bağlantı Hatası

**Kontrol Et:**
1. Build Args'da SOURCEBASE_SUPABASE_URL doğru mu?
2. SOURCEBASE_SUPABASE_ANON_KEY geçerli mi?
3. Supabase projesi aktif mi?

**Çözüm:**
```bash
# Browser console'da kontrol et
console.log(window.location.href)
# Network tab'da Supabase isteklerini kontrol et

# Build Args'ı güncelle ve rebuild et
Coolify → Settings → Build Args → Save → Deploy
```

---

## 📊 Build Süreleri

| Aşama | Süre | Açıklama |
|-------|------|----------|
| Git Clone | ~10s | Repository indirilir |
| Flutter Dependencies | ~2-3 dk | İlk build'de, sonra cache |
| Flutter Build Web | ~2-3 dk | Dart → JavaScript compile |
| Docker Image Build | ~30s | Nginx image + copy files |
| Container Start | ~5s | Nginx başlatılır |
| **Toplam** | **~5-8 dk** | İlk build, sonraki ~3-5 dk |

---

## 🎯 Başarı Kriterleri

Deployment başarılı sayılır eğer:

- ✅ Build logs'da hata yok
- ✅ Container "running" durumda
- ✅ Health check başarılı (200 OK)
- ✅ Domain'e HTTPS ile erişilebilir
- ✅ Login ekranı yükleniyor
- ✅ Supabase auth çalışıyor
- ✅ Console'da kritik hata yok
- ✅ Cache headers doğru yapılandırılmış

---

## 📚 Dokümantasyon

- **Hızlı Başlangıç**: [COOLIFY_QUICK_START.md](./COOLIFY_QUICK_START.md)
- **Detaylı Rehber**: [COOLIFY_DEPLOYMENT_GUIDE.md](./COOLIFY_DEPLOYMENT_GUIDE.md)
- **Production Checklist**: [PRODUCTION_READY.md](./PRODUCTION_READY.md)
- **Build Test**: `./test_build.sh`
- **Deploy Script**: `./deploy.sh`

---

## 🎉 Deployment Tamamlandı!

Tüm checklistler tamamlandıysa:

**🌐 Canlı URL**: https://sourcebase.medasi.com.tr

### Sonraki Adımlar

1. **Kullanıcı Testi**: Gerçek kullanıcılarla test et
2. **Performance Optimization**: Lighthouse önerilerini uygula
3. **Monitoring Setup**: Uptime ve error tracking ekle
4. **Documentation**: Kullanıcı dokümantasyonu hazırla
5. **Marketing**: Duyuru yap! 🚀

---

**Hazırlayan**: AI Assistant  
**Tarih**: 2026-05-16  
**Versiyon**: 1.0.0  
**Durum**: ✅ Ready for Production
