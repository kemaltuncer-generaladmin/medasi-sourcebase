# MASTER_PROMPT.md — Opencode Go İçin Ana Çalıştırma Promptu

Aşağıdaki promptu Opencode Go'ya ver.

---

Sen bu repo üzerinde çalışan Opencode Go ajanısın.

Bu çalışmanın amacı SourceBase üzerinde senin ne kadar güvenli, kontrollü ve premium tasarım iyileştirmesi yapabildiğini test etmektir.

Önce root klasördeki şu dosyaları oku:

```txt
AGENTS.md
DESIGN_SYSTEM.md
SCREEN_REVIEW_GUIDE.md
PATCH_PROTOCOL.md
SWIFT_EXPERIMENT_GUARDRAILS.md
OPENCODE_FIRST_TASK.md
```

Bu dosyalar bağlayıcıdır.

---

# Ana Hedef

SourceBase'i çalışan akışları bozmadan, mobilde daha premium, sade, klinik ve güvenilir hale getirmek.

İlk görevde sadece Drive ekranlarına odaklan.

---

# Mutlak Kurallar

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
- Önce inceleme raporu ver.
- Sonra küçük patch uygula.
- Sonra test çalıştır.
- Sonra sonuç raporu ver.

---

# İlk Görev

Sadece SourceBase Drive ekranlarını incele ve en küçük güvenli premium tasarım patch'ini uygula.

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

---

# Önce Rapor Ver

Kod yazmadan önce şu raporu ver:

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

Rapor verdikten sonra patch uygula.

---

# Patch Hedefleri

İlk patch şunları iyileştirmeli:

1. Header sadeleşsin
2. Upload CTA daha güçlü olsun
3. File card'lar daha ferah olsun
4. Status badge'ler daha net olsun
5. Empty state daha yönlendirici olsun
6. Error state daha insani olsun
7. Processing state daha güven verici olsun
8. Bottom nav/safe area problemi varsa düzelsin
9. Hazır olmayan dosyalar üretime uygun gibi görünmesin

---

# Tasarım Dili

Kaynak dil:

```txt
Klinik
Sade
Premium
Güvenilir
Ferah
Medikal SaaS
Tıp öğrencisi odaklı
```

Yasak dil:

```txt
Neon
Robotik
AI magic
Sihirli
Kripto/fintech hissi
Aşırı gradient
Stok yapay zeka tasarımı
```

---

# Patch Sonrası Test

Şu komutları çalıştır:

```bash
flutter analyze
flutter test
flutter build web --release
```

Başarısız olursa minimum fix yap ve tekrar çalıştır.

---

# Final Rapor

Patch sonunda şu formatta raporla:

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

---

# Başarı Tanımı

Bu görev başarılı sayılırsa:

- Drive ekranı daha premium görünür
- kullanıcı yeni kaynak yükleme aksiyonunu daha net görür
- dosya durumları daha anlaşılır olur
- empty/error/loading state daha güven verir
- ana akış bozulmaz
- testler geçer
- Qlinik etkilenmez

Başla.
