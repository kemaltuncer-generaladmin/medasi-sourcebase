# OPENCODE_FIRST_TASK.md — Opencode Go İlk Görev

Bu görev, Opencode Go'nun SourceBase üzerinde ne kadar güvenli ve kaliteli tasarım iyileştirmesi yapabildiğini test etmek için hazırlanmıştır.

---

# Görev

Sadece SourceBase Drive ekranlarını incele ve en küçük güvenli premium tasarım patch'ini uygula.

---

# Bağlayıcı Dosyalar

Önce şu dosyaları oku:

```txt
AGENTS.md
DESIGN_SYSTEM.md
SCREEN_REVIEW_GUIDE.md
PATCH_PROTOCOL.md
```

Bu dosyalardaki kurallar bağlayıcıdır.

---

# Kapsam

Sadece Drive kullanıcı arayüzü:

- Drive Home
- Dosya kartları
- Upload CTA
- Empty state
- Loading/processing state
- Error state
- Status badge
- Bottom safe area/padding

---

# Kapsam Dışı

Dokunma:

- Qlinik
- backend
- auth logic
- upload API logic
- complete_upload logic
- generation logic
- MC/refund
- Store
- Profile
- SourceLab
- Swift denemesi
- dependency ekleme

---

# İlk Adım: Kod Yazmadan Raporla

Önce rapor ver:

```md
## Drive İnceleme Raporu

### Bulduğum Drive Dosyaları
- ...

### Mevcut UI Sorunları
1. ...
2. ...
3. ...

### P0/P1/P2 Öncelikler
- P0:
- P1:
- P2:

### İlk Küçük Patch Önerisi
...

### Dokunulacak Dosyalar
- ...

### Dokunulmayacak Dosyalar
- ...
```

---

# Patch Hedefi

İlk patch şunları iyileştirmeli:

1. Header daha sade ve güvenilir olsun
2. Upload CTA daha görünür ve güçlü olsun
3. File card'lar daha ferah olsun
4. Status badge'ler daha anlaşılır olsun
5. Empty/error/loading state metinleri daha kullanıcı dostu olsun
6. Bottom nav/safe area içerik kapatmasın
7. Ready olmayan dosyalar üretime uygun gibi görünmesin

---

# Tasarım Dili

Uygula:

- klinik
- sade
- premium
- güvenilir
- mobilde ferah
- tıp öğrencisine uygun

Kaçın:

- neon
- robotik AI dili
- aşırı gradient
- çok kalabalık kart
- gereksiz pazarlama metni
- teknik hata metni

---

# Test

Patch sonrası çalıştır:

```bash
flutter analyze
flutter test
flutter build web --release
```

Eğer komutlardan biri başarısız olursa:

1. Hata çıktısını oku
2. Root cause belirt
3. Minimum fix yap
4. Testi tekrar çalıştır
5. Hâlâ başarısızsa dur ve raporla

---

# Son Rapor

Patch sonrası şu formatta rapor ver:

```md
## Yapılan İş

...

## Değişen Dosyalar

- ...

## Kullanıcı Deneyimi Etkisi

...

## Korunan Alanlar

- Qlinik'e dokunulmadı
- Backend contract değişmedi
- Auth/upload/generation logic değişmedi
- Secret eklenmedi

## Test Sonuçları

- flutter analyze: PASS/FAIL
- flutter test: PASS/FAIL
- flutter build web --release: PASS/FAIL

## Kalan Riskler

...

## Sonraki En Güvenli Adım

...
```
