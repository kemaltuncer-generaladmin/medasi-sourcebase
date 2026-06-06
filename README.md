# SourceBase (iOS)

Flutter "Cardstation" uygulamasının backend'i korunarak arayüzü sıfırdan yazılan SwiftUI sürümü.

## Klasör yapısı

```
swiftsourcebase/
├── App/                  → Xcode app projesi (TestFlight buradan paketlenir)
│   ├── SourceBase.xcodeproj
│   ├── SourceBase/       → @main, Info.plist, app icon
│   └── TESTFLIGHT.md     → adım adım yükleme rehberi
├── SourceBaseiOS/        → SwiftUI arayüz katmanı (SPM paketi)
├── SourceBaseBackend/    → Supabase backend katmanı (SPM paketi)
└── docs/                 → ajan yönergeleri, tasarım sistemi, promptlar
```

## Mimari

- **`SourceBaseBackend`** — Supabase'e bağlanan backend. Config `SourceBaseConfig`'te
  gömülü default'larla gelir (TestFlight'ta environment değişkeni olmadığı için).
- **`SourceBaseiOS`** — tüm ekranlar ve tasarım sistemi. `SourceBaseBackend`'e bağımlı.
  Uygulama girişi `SourceBaseRootView`.
- **`App`** — iki paketi gömüp `@main` ile çalıştırılabilir uygulamaya çeviren ince Xcode katmanı.

## Geliştirme

```bash
# Paketleri tek başına derlemek / test etmek
cd SourceBaseiOS && swift build && swift test

# Uygulamayı simülatörde derlemek
cd App && xcodebuild -project SourceBase.xcodeproj -scheme SourceBase \
  -destination 'generic/platform=iOS Simulator' build
```

## TestFlight

Bkz. [App/TESTFLIGHT.md](App/TESTFLIGHT.md). Özet: Xcode'da `App/SourceBase.xcodeproj`'i aç,
Signing'de Team'i seç, **Product → Archive**, Organizer'dan yükle.

- **Bundle ID:** `tr.com.medasi.sourcebase`
- **Min iOS:** 17.0
- **Sürüm:** 1.0.0 (build 1)
