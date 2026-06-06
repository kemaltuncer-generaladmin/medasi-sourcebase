# PATCH_PROTOCOL.md — SourceBase Güvenli Patch Protokolü

Bu dosya, Opencode Go'nun her değişiklikte takip edeceği protokolü tanımlar.

Amaç: Küçük, güvenli, test edilebilir, geri alınabilir değişiklikler yapmak.

---

# 1. Patch Öncesi Zorunlu Kontrol

Her patch öncesi aşağıdaki soruları cevapla:

```md
## Patch Öncesi Kontrol

### Görev
Bu patch neyi düzeltecek?

### Kapsam
Hangi ekran/modül?

### Dokunulacak Dosyalar
- ...

### Dokunulmayacak Alanlar
- Qlinik
- Backend contract
- Auth logic
- Upload logic
- Generation logic
- Secrets

### Risk
Bu değişiklik neyi bozabilir?

### Test
Patch sonrası hangi komutlar çalışacak?
```

Bu kontrol yapılmadan kod yazma.

---

# 2. Patch Boyutu

İdeal patch:

- 1 ekran
- 1 component
- 1 state
- 1 bug
- 1 test grubu

Riskli patch:

- 5+ ekran
- 10+ dosya
- navigation + theme + backend aynı anda
- yeni dependency
- büyük klasör taşıma
- dosya adı değişiklikleri

Riskli patch gerekliyse önce raporla, uygulama yapma.

---

# 3. Dosya Dokunma Kuralları

## 3.1 Flutter UI Patch

Dokunulabilir:

```txt
lib/features/sourcebase/...
lib/features/drive/...
lib/features/baseforce/...
lib/features/sourcelab/...
lib/shared/sourcebase_ui/...
```

Ama gerçek path projeye göre değişebilir. Önce bul, sonra raporla.

Dokunulmaz:

```txt
ios/
android/ build ayarları
qlinik feature dosyaları
.env
backend secrets
```

## 3.2 Swift Package Patch

Dokunulabilir:

```txt
SourceBaseKit/
```

Dokunulmaz:

```txt
lib/
ios/
supabase/functions/
.env
Qlinik dosyaları
```

## 3.3 Backend Patch

Backend patch sadece kullanıcı açıkça istediğinde yapılır.

Varsayılan olarak:

```txt
Backend'e dokunma.
```

---

# 4. Test Protokolü

## 4.1 Flutter Değişiklikleri

Sırayla çalıştır:

```bash
flutter analyze
flutter test
flutter build web --release
```

## 4.2 Swift Package Değişiklikleri

Sırayla çalıştır:

```bash
swift build
swift test
```

## 4.3 iOS App Değişiklikleri

Eğer Xcode projesi/scheme varsa:

```bash
xcodebuild -scheme <SCHEME_NAME> -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## 4.4 Test Başarısızlığı

Test başarısız olursa:

1. Hata çıktısını oku
2. Root cause belirt
3. Minimum fix yap
4. Aynı testi tekrar çalıştır
5. Başarısızlık devam ederse raporla ve dur

---

# 5. Rapor Formatı

Her patch sonrası şu format zorunludur:

```md
## Yapılan İş

...

## Değişen Dosyalar

- ...

## Davranış Değişikliği

- Var/Yok
- Varsa açıklama

## Korunan Alanlar

- Qlinik'e dokunulmadı
- Backend contract değişmedi
- Secret eklenmedi
- Auth/upload/generation logic korunuyor

## Test Sonuçları

- flutter analyze: PASS/FAIL/ÇALIŞTIRILMADI
- flutter test: PASS/FAIL/ÇALIŞTIRILMADI
- flutter build web --release: PASS/FAIL/ÇALIŞTIRILMADI
- swift build: PASS/FAIL/ÇALIŞTIRILMADI
- swift test: PASS/FAIL/ÇALIŞTIRILMADI

## Görsel/Kullanıcı Etkisi

...

## Kalan Riskler

...

## Sonraki En Güvenli Adım

...
```

---

# 6. Tasarım Patch Kabul Kriterleri

Bir tasarım patch'i ancak şu şartlarda kabul edilebilir:

- kullanıcı akışı daha net oldu
- ekran daha ferah oldu
- ana aksiyon daha görünür oldu
- status/error/loading/empty state iyileşti
- mobile safe area bozulmadı
- backend logic değişmedi
- Qlinik etkilenmedi
- testler çalıştırıldı

---

# 7. Geri Alma Güvenliği

Her patch geri alınabilir olmalı.

Kaçın:

- dosya silme
- klasör taşıma
- ortak component API'sini bozma
- route isimlerini değiştirme
- model alanlarını değiştirme
- backend payload adlarını değiştirme

---

# 8. İlk Patch İçin Önerilen Protokol

İlk görev:

```txt
Drive Home ekranında küçük tasarım polish.
```

Beklenen küçük değişiklikler:

- header metni sadeleşir
- upload CTA güçlenir
- file card spacing iyileşir
- status badge netleşir
- empty/error/loading state metinleri iyileşir
- bottom padding/safe area kontrol edilir

Yasak:

- upload API değiştirme
- complete_upload logic değiştirme
- dosya ingestion değiştirme
- route yapısını değiştirme
- Qlinik'e dokunma
