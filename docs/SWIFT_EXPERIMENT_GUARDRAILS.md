# SWIFT_EXPERIMENT_GUARDRAILS.md — SourceBase Swift / SourceBaseKit Deneme Sınırları

Bu dosya, SourceBase için Swift tarafında yapılacak deneylerde sınırları belirler.

Amaç: Swift denemesi ana Flutter projesini, canlı backend'i ve Qlinik'i riske atmadan ilerlesin.

---

# 1. Denemenin Amacı

Swift denemesinin amacı:

```txt
Canlı SourceBase backend'e bağlanabilecek temiz bir Swift client katmanı ve ileride native iOS frontend için temel oluşturmak.
```

Denemenin amacı değildir:

```txt
Backend'i Swift'e kopyalamak
Canlı backend'i değiştirmek
Flutter uygulamasını hemen çöpe atmak
Qlinik'i etkilemek
```

---

# 2. İsimlendirme

Tercih edilen klasör adı:

```txt
SourceBaseKit
```

Kaçınılması gereken ad:

```txt
SourceBaseBackend
```

Çünkü bu gerçek backend değildir.

Doğru anlam:

```txt
SourceBaseKit = Swift tarafında SourceBase backend ile konuşan client SDK
```

---

# 3. Dosya Konumu

Doğru:

```txt
Cardstation/
├── SourceBaseKit/
│   ├── Package.swift
│   ├── Sources/SourceBaseKit/
│   └── Tests/SourceBaseKitTests/
├── lib/
└── ...
```

Yanlış:

```txt
Cardstation/ios/SourceBaseKit/
Cardstation/lib/SourceBaseKit/
Cardstation/supabase/functions/swift-copy/
```

Neden?

Flutter `ios/` klasörü Flutter tooling tarafından yeniden üretilebilir.
Swift denemesi Flutter'a bulaşmadan root'ta kalmalıdır.

---

# 4. Teknik Seçimler

## 4.1 Package Manager

Kullanılacak yapı:

```txt
Swift Package Manager
```

Sebep:

- sade
- hızlı
- Xcode uyumlu
- merge conflict riski düşük
- bağımsız test edilebilir

## 4.2 Test

Kullanılacak test altyapısı:

```txt
XCTest
```

Sebep:

- production standardı
- Apple ekosisteminde olgun
- SPM ile sorunsuz
- Xcode uyumlu

## 4.3 Dependency

Varsayılan olarak dependency ekleme.

Gerekirse tek dış bağımlılık:

```txt
supabase-swift
```

Başka bağımlılık ekleme.

---

# 5. Secret Güvenliği

Client package içine hiçbir secret gömülmez.

Yasak:

```txt
service_role key
GCS private key
Vertex private key
OpenAI/Anthropic key
private token
production JWT
```

Kabul edilebilir:

```txt
public Supabase URL placeholder
public anon/publishable key placeholder
environment/xcconfig üzerinden okuma
testlerde mock value
```

Gerçek değerler:

- commitlenmez
- print edilmez
- test loguna düşmez

---

# 6. Modül Yapısı

Önerilen yapı:

```txt
SourceBaseKit/
├── Package.swift
├── Sources/
│   └── SourceBaseKit/
│       ├── Config/
│       │   └── SourceBaseConfig.swift
│       ├── Core/
│       │   ├── SourceBaseAPIClient.swift
│       │   ├── SourceBaseError.swift
│       │   ├── SourceBaseEndpoint.swift
│       │   └── JSONCoding.swift
│       ├── Auth/
│       │   ├── AuthService.swift
│       │   ├── AuthModels.swift
│       │   └── AuthSessionStore.swift
│       ├── Drive/
│       │   ├── DriveService.swift
│       │   ├── DriveModels.swift
│       │   ├── UploadService.swift
│       │   └── UploadModels.swift
│       ├── Generation/
│       │   ├── GenerationService.swift
│       │   └── GenerationModels.swift
│       └── Profile/
│           ├── ProfileService.swift
│           └── ProfileModels.swift
└── Tests/
    └── SourceBaseKitTests/
        ├── ConfigTests.swift
        ├── AuthModelTests.swift
        ├── DriveContractTests.swift
        ├── UploadContractTests.swift
        └── GenerationContractTests.swift
```

---

# 7. Backend Contract İlkesi

Swift tarafı backend'e uyacak.

Backend Swift'e uymak için değiştirilmeyecek.

Önce Flutter kodundan veya mevcut client'tan şu kontratlar çıkarılır:

```txt
endpoint
method
headers
action
request body
response body
status values
error format
```

Sonra Swift modelleri buna göre yazılır.

---

# 8. MVP Contract Akışları

İlk Swift client MVP şu akışları kapsar:

## 8.1 Auth

- login
- token/session saklama interface'i
- authorization header üretme
- logout/session clear

## 8.2 Drive

- drive_bootstrap
- file list decode
- file status mapping
- file detail model
- ready/processing/error/unsupported states

## 8.3 Upload

- create_upload_session
- signed URL PUT için request bilgisi
- complete_upload
- status polling contract

## 8.4 Generation

- create_generation_job
- process_generation_job
- job status polling
- generated output decode

## 8.5 Profile

- basic profile model
- user info decode

---

# 9. Test İlkeleri

İlk testler canlı backend'e vurmak zorunda değildir.

Öncelik contract testleri:

- JSON encode doğru mu?
- JSON decode doğru mu?
- action string doğru mu?
- error mapping doğru mu?
- status mapping doğru mu?
- config validation doğru mu?

Örnek testler:

```txt
create_generation_job payload action doğru mu?
process_generation_job payload action doğru mu?
complete_upload request modeli beklenen alanları içeriyor mu?
ready/processing/error statusları doğru enum'a map oluyor mu?
```

---

# 10. Yasaklar

Swift denemesinde yasak:

- backend endpoint değiştirme
- server-side logic yazma
- edge function copy/paste edip Swift'te backend yapmak
- secret gömme
- Flutter lib/ içine kod koyma
- Flutter ios/ içine kalıcı package koyma
- Qlinik import/refactor
- test yazmadan büyük kod üretme

---

# 11. Swift UI Denemesi Yapılırsa

Eğer SourceBaseKit üstüne SwiftUI frontend kurulacaksa:

Öncelik:

```txt
Login
Drive list
PDF upload
Ready state
BaseForce home
Flashcard generation
Result detail
```

Kapsam dışı:

```txt
Store
Full Profile
Full SourceLab
Mind map
Infographic
Podcast
Admin
```

---

# 12. Kabul Kriteri

Swift denemesi başarılı sayılır:

- SourceBaseKit bağımsız build alıyorsa
- XCTest geçiyorsa
- secret içermiyorsa
- Flutter'a dokunmuyorsa
- backend sözleşmesini değiştirmiyorsa
- Qlinik'e dokunmuyorsa
- endpoint/action/payload contract'ı açıkça modellenmişse

Başarısız sayılır:

- backend fork'u oluştuysa
- canlı backend'e uyumsuz payload üretildiyse
- secret koda gömüldüyse
- Flutter projesi bozulduysa
- Qlinik etkilenme riski doğduysa
