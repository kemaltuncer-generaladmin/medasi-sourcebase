# Opencode Go'ya Direkt Yapıştırılacak Prompt

Root klasördeki directive dosyalarını oku ve aşağıdaki görevi uygula.

Önce şu dosyaları oku:

- AGENTS.md
- DESIGN_SYSTEM.md
- SCREEN_REVIEW_GUIDE.md
- PATCH_PROTOCOL.md
- SWIFT_EXPERIMENT_GUARDRAILS.md
- OPENCODE_FIRST_TASK.md

Bu dosyalardaki kurallar bağlayıcıdır.

Görev: SourceBase Drive ekranlarında en küçük güvenli premium tasarım patch'ini uygula.

Mutlak kurallar:

- Qlinik'e dokunma.
- Backend endpoint/action/payload sözleşmesini değiştirme.
- Auth logic değiştirme.
- Upload logic değiştirme.
- Generation logic değiştirme.
- MC/refund mantığına dokunma.
- Secret, token, private key, service role key, storage provider key, Vertex key yazma.
- `.env` içeriğini print etme.
- Yeni dependency ekleme.
- Büyük refactor yapma.
- Commit atma.

Kapsam:

- Drive Home
- Dosya kartları
- Upload CTA
- Empty state
- Loading/processing state
- Error state
- Status badge
- Bottom safe area/padding

Kapsam dışı:

- Qlinik
- Backend
- Auth
- Upload API implementation
- Generation
- Store
- Profile
- SourceLab
- Swift denemesi

Önce kod yazmadan rapor ver:

```md
## Drive İnceleme Raporu

### Okunan Kılavuzlar
- AGENTS.md
- DESIGN_SYSTEM.md
- SCREEN_REVIEW_GUIDE.md
- PATCH_PROTOCOL.md
- OPENCODE_FIRST_TASK.md

### Bulduğum Drive Dosyaları
- ...

### Mevcut Tasarım Sorunları
1. ...
2. ...
3. ...
4. ...
5. ...

### Önceliklendirme
- P0:
- P1:
- P2:

### En Küçük Güvenli Patch
...

### Dokunulacak Dosyalar
- ...

### Dokunulmayacak Alanlar
- Qlinik
- Backend
- Auth
- Upload logic
- Generation logic
- Secrets

### Riskler
...
```

Rapor sonrası patch uygula.

Patch hedefleri:

1. Header sadeleşsin.
2. Upload CTA daha güçlü olsun.
3. File card'lar daha ferah olsun.
4. Status badge'ler daha net olsun.
5. Empty state daha yönlendirici olsun.
6. Error state daha insani olsun.
7. Processing state daha güven verici olsun.
8. Bottom nav/safe area problemi varsa düzelsin.
9. Hazır olmayan dosyalar üretime uygun gibi görünmesin.

Tasarım dili:

- klinik
- sade
- premium
- güvenilir
- ferah
- medikal SaaS
- tıp öğrencisi odaklı

Kaçın:

- neon
- robotik
- AI magic
- sihirli
- kripto/fintech hissi
- aşırı gradient
- stok yapay zeka tasarımı

Patch sonrası çalıştır:

```bash
flutter analyze
flutter test
flutter build web --release
```

Final raporu şu formatta ver:

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
- Dependency eklenmedi

## Test Sonuçları

- flutter analyze: PASS/FAIL
- flutter test: PASS/FAIL
- flutter build web --release: PASS/FAIL

## Kalan Riskler

...

## Sonraki En Güvenli Adım

...
```

Başla.
