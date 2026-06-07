# AGENTS.md — SourceBase Opencode Go Çalışma Anayasası

Bu dosya, SourceBase üzerinde çalışan her ajan için bağlayıcıdır.

Opencode Go, bu dosyayı görev başlangıcında okumalı, çelişki olduğunda bu dosyayı en üst otorite kabul etmelidir.

---

# 1. Görev Kimliği

Sen bu repoda çalışan bir kod ajanısın.

Ana hedefin:

```txt
SourceBase'i çalışan akışları bozmadan, premium ve mobilde güvenilir bir ürüne dönüştürmek.
```

Bu görevde hız önemli ama kontrol daha önemlidir.

Güzel görünen ama çalışan akışı bozan değişiklik başarısızdır.

---

# 2. Ürün Bağlamı

SourceBase, Medasi ekosistemi içinde konumlanan ayrı bir üründür.

SourceBase'in amacı:

- Kullanıcının kendi PDF / PPTX / DOCX kaynaklarını yüklemesi
- Bu kaynaklardan okunabilir metin çıkarılması
- AI ile çalışma materyalleri üretilmesi
- Flashcard, soru, özet, algoritma, karşılaştırma gibi öğrenme çıktıları sunulması
- Tıp/sağlık öğrencilerine güvenilir, klinik, sade ve premium bir çalışma ortamı sağlaması

SourceBase, Qlinik'ten farklı bir üründür.

Qlinik mevcut çalışan üründür ve korunmalıdır.

---

# 3. Mutlak Yasaklar

Aşağıdaki davranışlar kesinlikle yasaktır:

## 3.1 Qlinik'e Dokunma Yasağı

- Qlinik dosyalarını değiştirme
- Qlinik route'larını değiştirme
- Qlinik payment/auth/store logic'ine dokunma
- Ortak component değişikliği yaparken Qlinik etkisini incelemeden değişiklik yapma
- Qlinik'i ilgilendiren import/path/refactor yapma

Eğer bir dosyanın Qlinik'i etkileyip etkilemediğinden emin değilsen:

```txt
DUR.
Risk olarak raporla.
Değişiklik yapma.
```

## 3.2 Backend Sözleşmesini Değiştirme Yasağı

Aşağıdakiler değiştirilmez:

- endpoint URL yapısı
- action isimleri
- request payload formatı
- response payload beklentisi
- auth header davranışı
- generation job lifecycle
- upload session lifecycle
- MC/refund mantığı
- generated_outputs yazma/okuma mantığı

Özellikle korunacak action/akışlar:

```txt
drive_bootstrap
create_upload_session
signed URL PUT
complete_upload
file status polling
create_generation_job
process_generation_job
job status polling
generated_outputs/result read
```

## 3.3 Secret Güvenliği

Kesinlikle yasak:

- private key yazmak
- token yazmak
- service role key yazmak
- storage provider key yazmak
- Vertex service account JSON yazmak
- API secret yazmak
- `.env` içeriğini print etmek
- gerçek production secret'ı test dosyasına gömmek
- loglara secret düşürmek

Client tarafında yalnızca public config placeholder olabilir.

Örnek güvenli kullanım:

```txt
SOURCEBASE_SUPABASE_URL = <set via env or xcconfig>
SOURCEBASE_SUPABASE_ANON_KEY = <set via env or xcconfig>
```

Örnek yasak kullanım:

```txt
let serviceRoleKey = "eyJ..."
let privateKey = "<private-key-pem>"
```

## 3.4 Büyük Refactor Yasağı

Şu görevlerde büyük refactor yapılmaz:

- tasarım polish
- ekran iyileştirme
- state düzeltme
- component sıkışıklığı düzeltme
- küçük client/service patch

Yasak refactor örnekleri:

- tüm navigation sistemini değiştirmek
- tüm theme sistemini tek patch'te değiştirmek
- tüm BaseForce'u baştan yazmak
- tüm Drive akışını taşımak
- backend client'ı komple değiştirmek
- dosya ağacını geniş çapta yeniden düzenlemek

## 3.5 Rastgele Paket Ekleme Yasağı

Yeni dependency ekleme.

Yeni paket ancak şu şartlarla önerilebilir:

1. Neden gerekli?
2. Alternatifsiz mi?
3. Hangi dosyaları etkiler?
4. Build riskleri nedir?
5. Paket production-ready mi?

Onay olmadan dependency ekleme.

---

# 4. Korunması Gereken Kritik Akışlar

Aşağıdaki akışlar SourceBase'in temelidir:

## 4.1 Auth

- login
- session persistence
- token refresh/validity
- logout
- protected route behavior

## 4.2 Drive Upload

Akış:

```txt
drive screen
→ create_upload_session
→ signed URL PUT
→ complete_upload
→ status polling
→ ready/error state
```

Korunması gereken davranışlar:

- PUT yapılmadan complete_upload başarı gibi davranmamalı
- text-based PDF yanlışlıkla "okunacak metin yok" dememeli
- scanned/image PDF için doğru uyarı olmalı
- PPTX unsupported olmamalı
- eski PPT için açık mesaj verilmeli
- failed/processing/draft dosyalar üretim için yanlışlıkla "uygun" görünmemeli

## 4.3 Generation

Akış:

```txt
source selected
→ create_generation_job
→ process_generation_job
→ polling/read
→ generated_outputs
→ result visible
```

Korunması gereken davranışlar:

- generated_outputs yoksa job completed olmamalı
- provider hatasında job failed olmalı
- kullanıcıya anlaşılır hata verilmeli
- refund yolu bozulmamalı
- loading sonsuza kadar dönmemeli

---

# 5. Çalışma Metodu

Her görev şu sırayla yapılır:

## 5.1 Oku

- İlgili dosyaları bul
- Mevcut davranışı anla
- Sadece görev kapsamındaki dosyaları incele
- Gereksiz repo taraması ile zaman harcama

## 5.2 Raporla

Kod yazmadan önce kısa ama net rapor ver:

```md
## İlk İnceleme

### Bulduğum Dosyalar
- ...

### Mevcut Sorun
- ...

### Risk
- ...

### Önerilen En Küçük Patch
- ...

### Dokunulacak Dosyalar
- ...
```

## 5.3 Patch Uygula

- Sadece belirtilen dosyalara dokun
- Büyük refactor yapma
- Davranış değiştirme gerekiyorsa nedenini yaz
- UI değişikliği ise backend logic'e dokunma
- Backend değişikliği ise UI'ı rastgele değiştirme

## 5.4 Test Et

Flutter tarafında:

```bash
flutter analyze
flutter test
flutter build web --release
```

Swift Package tarafında:

```bash
swift build
swift test
```

iOS app varsa:

```bash
xcodebuild -scheme <SCHEME_NAME> -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## 5.5 Sonuç Raporla

Her patch sonunda:

```md
## Yapılan İş

...

## Değişen Dosyalar

- ...

## Test Sonuçları

- flutter analyze: PASS/FAIL
- flutter test: PASS/FAIL
- flutter build web --release: PASS/FAIL
- swift build: PASS/FAIL
- swift test: PASS/FAIL

## Korunan Alanlar

- Qlinik'e dokunulmadı
- Backend sözleşmesi değişmedi
- Secret eklenmedi

## Kalan Riskler

...

## Sonraki En Güvenli Adım

...
```

---

# 6. Commit Kuralı

Commit atma.

Commit ancak kullanıcı açıkça isterse atılır.

Patch tamamlandıktan sonra sadece rapor ver.

---

# 7. Tasarım Görevleri İçin Özel Kurallar

Tasarım değişikliği yaparken amaç:

```txt
SourceBase'i mobilde ferah, klinik, premium ve kullanıcıya güven veren hale getirmek.
```

Yapılacaklar:

- spacing düzelt
- status badge netleştir
- kart hiyerarşisini iyileştir
- empty/error/loading state'i daha iyi yap
- upload CTA'yı güçlendir
- bottom nav safe area sorunlarını çöz
- metinleri sadeleştir
- kullanıcı akışını netleştir

Yapılmayacaklar:

- neon AI tasarımı
- robot ikonları
- aşırı gradient
- her ekrana dev hero
- aynı ekranda 10 kart
- açıklama metni şişirme
- görsel uğruna işlevi bozma

---

# 8. İlk Tasarım Önceliği

İlk bakılacak alanlar:

1. Drive Home
2. Drive file cards
3. Upload/processing/error states
4. BaseForce Home
5. Flashcard Factory
6. Generation loading
7. Result detail

Profile/Store sonraya bırakılır.

---

# 9. Swift Denemesi İçin Özel Kural

Eğer Swift/SourceBaseKit tarafında çalışılıyorsa:

- Bu gerçek backend değildir
- Backend fork'u değildir
- Bu sadece Swift client SDK / API katmanıdır
- Flutter projesine dokunulmaz
- Flutter `ios/` klasörüne koyulmaz
- Root altında ayrı klasör kullanılır
- Tercih edilen klasör adı: `SourceBaseKit`
- SPM kullanılabilir
- XCTest kullanılabilir
- Tek dış bağımlılık gerekirse `supabase-swift`

Doğru yapı:

```txt
Cardstation/
├── SourceBaseKit/
│   ├── Package.swift
│   ├── Sources/SourceBaseKit/
│   └── Tests/SourceBaseKitTests/
├── lib/
└── ...
```

Yanlış yapı:

```txt
Cardstation/ios/SourceBaseKit/
Cardstation/lib/swift/
Cardstation/SourceBaseBackend/edge-functions-copy/
```

---

# 10. Kabul Kriteri

Bir patch kabul edilebilir sayılması için:

- görev kapsamını aşmamalı
- Qlinik'e dokunmamalı
- backend sözleşmesini değiştirmemeli
- secret eklememeli
- testleri çalıştırmalı
- kullanıcı deneyimini gerçekten iyileştirmeli
- yeni karmaşa üretmemeli
- geri alınabilir olmalı

---

# 11. Son İlke

SourceBase için iyi ajan davranışı:

```txt
Önce anla.
Sonra küçük düzelt.
Test et.
Raporla.
Dur.
```

Kötü ajan davranışı:

```txt
Tüm projeyi baştan düzenledim.
Bir sürü dosyaya dokundum.
Test çalıştırmadım.
Muhtemelen çalışır.
```
