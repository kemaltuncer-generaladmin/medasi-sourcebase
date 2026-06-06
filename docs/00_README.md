# SourceBase Opencode Go Directive Pack

> ⚠️ **ÖNEMLİ NOT:** Bu proje yarıda kalmıştır. Projenin ana amacı; Flutter kodundaki kullanıcı deneyimini okuyup sıfırdan mevcut backend'e uygun, premium bir SwiftUI tasarımı yazmaktı.

Bu paket, Opencode Go'nun SourceBase üzerinde kontrollü, güvenli, premium ve test edilebilir şekilde çalışması için hazırlanmıştır.

## Paket İçeriği

1. `AGENTS.md`
   - Ajan çalışma kuralları
   - Dokunulmaz alanlar
   - Güvenlik kuralları
   - Test ve rapor formatı
   - Flutter / Swift / backend sınırları

2. `DESIGN_SYSTEM.md`
   - SourceBase görsel dili
   - Renk, tipografi, spacing, kart, state, navigasyon kuralları
   - Premium mobil kabul kriterleri

3. `SCREEN_REVIEW_GUIDE.md`
   - Her ekranın insan gözüyle nasıl değerlendirileceği
   - Drive, BaseForce, Result, Empty/Error/Loading state inceleme kontrol listeleri

4. `OPENCODE_FIRST_TASK.md`
   - Opencode Go'ya verilecek ilk görev
   - Sadece Drive ekranlarında küçük ve güvenli tasarım patch'i

5. `PATCH_PROTOCOL.md`
   - Her patch öncesi/sonrası zorunlu protokol
   - Rapor formatı
   - Test komutları
   - Geri dönüş güvenliği

6. `SWIFT_EXPERIMENT_GUARDRAILS.md`
   - Swift/SourceBaseKit denemesi için sınırlar
   - Backend fork'u yapmama
   - Secret gömmeme
   - Flutter'a bulaşmama

7. `MASTER_PROMPT.md`
   - Opencode Go'ya tek seferde verilecek ayrıntılı prompt

## Kullanım

Bu dosyaları proje root'una koy:

```txt
Cardstation/
├── AGENTS.md
├── DESIGN_SYSTEM.md
├── SCREEN_REVIEW_GUIDE.md
├── PATCH_PROTOCOL.md
├── SWIFT_EXPERIMENT_GUARDRAILS.md
├── OPENCODE_FIRST_TASK.md
├── MASTER_PROMPT.md
├── lib/
└── ...
```

Sonra Opencode Go'ya `MASTER_PROMPT.md` içeriğini ver.

## Ana İlke

SourceBase'te çalışan akışı bozmak yasaktır.

Öncelik:

```txt
çalışır akış > net kullanıcı deneyimi > premium tasarım > mikro animasyon
```

Qlinik'e dokunulmayacak.
Backend sözleşmesi değiştirilmeyecek.
Secret yazılmayacak.
Büyük refactor yapılmayacak.
