# ⚡ Coolify Hızlı Başlangıç - SourceBase

**5 dakikada Coolify'da deploy et!**

---

## 🎯 Hızlı Adımlar

### 1️⃣ Coolify'da Yeni Uygulama Oluştur (2 dk)

```
Coolify Dashboard
  → + New Resource
  → Application
  → Git Repository
```

**Ayarlar:**
- **Repository**: GitHub/GitLab repo URL'niz
- **Branch**: `main`
- **Build Pack**: `Dockerfile` (otomatik algılanır)
- **Name**: `sourcebase` veya `kaynakmerkezi`
- **Domain**: `sourcebase.medasi.com.tr`
- **Port**: `80`

### 2️⃣ Build Args Ekle (1 dk)

**Settings → Build Args** sekmesine git ve ekle:

```bash
SOURCEBASE_SUPABASE_URL=https://medasi.com.tr
SOURCEBASE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlvdXItcHJvamVjdCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE5MTU2MDAwMDB9.your-signature
SOURCEBASE_PUBLIC_URL=https://sourcebase.medasi.com.tr
```

> 💡 **Supabase keys nasıl bulunur?**
> 1. https://supabase.com/dashboard → Projenizi seçin
> 2. Settings → API
> 3. **Project URL** → `SOURCEBASE_SUPABASE_URL`
> 4. **anon public** → `SOURCEBASE_SUPABASE_ANON_KEY`

### 3️⃣ Deploy Et! (5-8 dk)

```
Deploy butonuna tıkla → Build loglarını izle → Tamamlandı! 🎉
```

### 4️⃣ Test Et (1 dk)

```bash
# Health check
curl -I https://sourcebase.medasi.com.tr

# Tarayıcıda aç
open https://sourcebase.medasi.com.tr
```

---

## ✅ Başarı Kriterleri

Build başarılı ise:
- ✅ Build logs'da "Successfully built" görünür
- ✅ Container çalışır durumda
- ✅ Domain'e erişilebilir
- ✅ Login ekranı yüklenir
- ✅ Console'da kritik hata yok

---

## 🐛 Hızlı Sorun Giderme

### Build Hatası: "Flutter command not found"
**Çözüm**: Dockerfile doğru mu kontrol et (zaten düzeltildi ✅)

### Build Hatası: "pub get failed"
**Çözüm**: 
```bash
# Local'de test et
flutter pub get
git add pubspec.lock
git commit -m "Update dependencies"
git push
```

### Runtime: "Supabase URL is empty"
**Çözüm**: Build Args'ı kontrol et, rebuild et

### 404 Hatası: Routing çalışmıyor
**Çözüm**: nginx.conf doğru mu kontrol et (zaten düzeltildi ✅)

---

## 📚 Detaylı Dokümantasyon

Daha fazla bilgi için:
- [COOLIFY_DEPLOYMENT_GUIDE.md](./COOLIFY_DEPLOYMENT_GUIDE.md) - Tam deployment rehberi
- [PRODUCTION_READY.md](./PRODUCTION_READY.md) - Production checklist

---

## 🎉 Tamamlandı!

SourceBase artık Coolify'da çalışıyor!

**Canlı URL**: https://sourcebase.medasi.com.tr

### Otomatik Deployment İçin

**Settings → Source → Auto Deploy** toggle'ını aç

Artık her `git push` otomatik deploy tetikler! 🚀
