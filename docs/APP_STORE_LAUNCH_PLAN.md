# SourceBase — App Store Launch Plan (v1.0)

> **Amaç:** Uygulamayı App Store'a canlı gönderilebilecek kaliteye getirmek.
> **Bu doküman Sonnet 4.6'nın uygulayacağı bağlayıcı iş emridir.** Her madde `dosya:satır` referanslı, P0/P1/P2 önceliklendirilmiş ve tek tek uygulanabilir yazıldı.
> **Hazırlayan:** Opus (denetim + plan). **Uygulayan:** Sonnet 4.6 (kod).
> **Karar verilenler:** (1) Coin satışı StoreKit 2 IAP'ye taşınacak (web akışı duruyor). (2) Gizlilik/Şartlar URL'leri ve hesap-silme backend'i hazır; sadece UI'a bağlanacak.

---

## 0. DURUM ÖZETİ

Uygulama olgun: 86 Swift dosyası, ~19k satır, çalışan tasarım sistemi (SB* token + component), Shimmer/Pow/Lottie kurulu, backend (Supabase) gerçek bağlı. Akışların büyük çoğunluğu **gerçek ve uçtan uca çalışıyor** (auth, drive, upload, generation, chat hepsi canlı Supabase'e gidiyor — sahte/mock yok).

**Yayını engelleyen 4 gerçek sorun var (P0):**
1. **StoreView harici ödeme linki** — Kural 3.1.1, garanti red. → StoreKit 2 IAP'ye taşı.
2. **PDF çıktısı tek sayfaya sığmayanı kesiyor** (`break` ile içeriği yutuyor) — premium çıktı vaadini bozar.
3. **Gizlilik Politikası / Kullanım Şartları linkleri tıklanamıyor** (kayıt ekranında düz metin) — Apple zorunlu.
4. **MedasiChat input bar klavyeyle çakışıyor** — açılış ekranı, ilk izlenim.

Geri kalan her şey P1 (görünür kalite) ve P2 (cila) seviyesinde. Auth akışı, hesap silme, çıkış, generation flow doğru kurulu.

**Önerilen uygulama sırası:** Bölüm 1 (IAP) → Bölüm 2 (P0'lar) → Bölüm 8 (PDF) → Bölüm 3 (tasarım sistemi geneli) → Bölüm 4 (ekran ekran P1) → Bölüm 5 (backend dayanıklılık) → Bölüm 6 (P2 cila) → Bölüm 9–10 (App Store Connect + build + QA).

---

## 1. [P0] StoreKit 2 IAP ENTEGRASYONU (en kritik, en uzun iş)

**Mevcut durum:** `StoreView.swift:414-462` `checkoutLinkSection` → `openURL(destination)` ve panoya kopyala ile tarayıcıda harici ödeme. Satılan şey "Medasi Coin" = uygulama içi tüketilen sanal para (AI üretim maliyeti). Bu, dijital tüketilebilir içerik → **StoreKit zorunlu**, harici link kesin red.

### 1.1 Strateji
- Coin paketleri **consumable** IAP ürünleri olarak App Store Connect'te tanımlanacak.
- App, StoreKit 2 ile satın alma yapacak; işlem doğrulanınca **backend'e coin kredilendirme** çağrısı atılacak.
- Web ödeme akışı (`checkoutUrl`) iOS'ta TAMAMEN devre dışı; sadece IAP gösterilecek.

### 1.2 App Store Connect ürün tanımları (kullanıcı/otomasyon yapacak — ürün ID şeması)
Her coin paketi için consumable ürün. Önerilen Product ID şeması:
```
tr.com.medasi.sourcebase.coin.<miktar>
örn: tr.com.medasi.sourcebase.coin.100, .coin.250, .coin.500, .coin.1000
```
> Backend'deki mevcut paket listesi (`StoreRepository.loadProducts()` → `store_products` tablosu, her satırda `coin_amount`) ile birebir eşleşmeli. Sonnet, `MedasiCoinPackage` modelinde her pakete bir `appStoreProductId` alanı ekleyecek; backend bu ID'yi dönmeli veya app tarafında `coin_amount → productId` map'i tutulmalı (geçici çözüm).
>
> **Coin ekonomisi (sunucudan teyit edildi — `services/medasicoin-pricing.ts`, `medasicoin-wallet.ts`):** Cüzdan `profiles.wallet_balance` alanında **MedasiCoin (MC)** olarak tutuluyor; `1 MC = 100 unit` (`MC_UNITS_PER_MC = 100`). Üretim maliyetleri unit cinsinden (örn central_ai std 10u=0.1MC, summary std 50u, flashcard std 75u, quiz std 100u, podcast 150u, infographic 300u, clinical 200u). Yani satılan paketler MC bazında; Product ID miktarları `store_products.coin_amount` (MC) ile eşleşmeli.

### 1.3 Kod mimarisi (yeni dosyalar)
**`SourceBaseiOS/Sources/SourceBaseiOS/Features/Profile/Store/SBStoreKitManager.swift`** (yeni):
- `@Observable @MainActor final class SBStoreKitManager`
- `func loadProducts(ids: [String]) async throws -> [Product]` (StoreKit `Product.products(for:)`)
- `func purchase(_ product: Product) async throws -> StoreKit.Transaction?`
  - `product.purchase()` → `.success(let verification)` → `checkVerified(verification)` → `transaction.finish()` SONRASI backend kredilendirme başarılıysa.
  - `.userCancelled` / `.pending` durumlarını ayrı handle et (pending = Ask to Buy, UI'da "onay bekleniyor").
- `func checkVerified<T>(_ result: VerificationResult<T>) throws -> T` (`.verified` → değer, `.unverified` → throw).
- `Transaction.updates` listener task: app açılışında başlat (uygulama dışı/iade/yeniden deneme işlemleri için), her gelen işlemi doğrula → backend'e bildir → `finish()`.
- `func restore() async` → `AppStore.sync()` (consumable'larda kullanıcıya bilgi amaçlı; consumable'lar restore edilmez ama buton App Store beklentisi).

**Backend kredilendirme contract'ı — SUNUCUDAN ÇIKARILDI, hazır referans desenleri var:**

Sunucu = self-hosted Supabase (`46.225.100.139`, Coolify). Edge functions container: `supabase-edge-functions-...`. SourceBase fonksiyonu: `/home/deno/functions/sourcebase/index.ts`.

- **JWS doğrulama HAZIR:** `praticase-storekit-verify/index.ts` zaten StoreKit 2 JWS doğrulamasını yapıyor (`_shared/apple_root_certificates.ts` ile Apple zincir doğrulaması, Sandbox/Production environment, bundleId kontrolü). Praticase bundle'ı `com.medasi.praticase`. **Sonnet/backend bunu SourceBase için kopyalayacak**, tek fark `bundleId = "tr.com.medasi.sourcebase"` ve coin kredilendirme hedefi sourcebase cüzdanı.
- **Kredilendirme deseni HAZIR:** SourceBase `index.ts`'de web ödemesi `payment_entitlement_webhook` (~satır 928) → `payment.entitlement_granted` olayında `sharedRpc("grant_store_product", {...})` çağırıyor; `purchases` tablosuna idempotent insert yapıyor (kontrol: `purchases?provider=eq.manual&provider_payment_id=eq.<id>`, ~960), `wallet_transactions`'a `type:"purchase", reason:"medasipay_purchase:<code>"` yazıyor (~1018).
- **YENİ action: `redeem_appstore_purchase`** (sourcebase fonksiyonuna eklenecek) — `payment_entitlement_webhook`'u BİREBİR aynala, tek fark kaynak:
  1. App gönderir `{ transactionId, productId, jws }` (StoreKit 2 `transaction.jwsRepresentation`).
  2. JWS'i `praticase-storekit-verify` mantığıyla doğrula (bundleId = sourcebase, productId eşleşmesi).
  3. Idempotency: `purchases` tablosunda `provider=eq.appstore & provider_payment_id=eq.<transactionId>` varsa tekrar kredilendirme — sadece mevcut bakiyeyi dön.
  4. Yeni ise `grant_store_product` RPC'sini productId↔coin_amount eşlemesiyle çağır, `purchases` (provider=`appstore`) + `wallet_transactions` (reason:`appstore_purchase:<productId>`) yaz.
  5. Güncel `wallet_balance` (MC) dön.
- App `DriveAPI`'ye `func redeemAppStorePurchase(transactionId:productId:jws:) async throws -> Double` ekler (yeni MC bakiyesi döner).
- **Önemli:** Kredilendirme backend'de DOĞRULANMADAN `transaction.finish()` çağırma; aksi halde ödeme alınır coin verilmez. Sıra: purchase → verify → backend redeem (başarılı) → finish. Backend redeem başarısızsa transaction'ı bitirme; `Transaction.updates` ile tekrar denenir (idempotency bunu güvenli kılar).

### 1.4 StoreView değişiklikleri
- `checkoutLinkSection` (414-462) ve tüm `openURL`/panoya-kopyala ödeme kodunu **iOS'ta sil** (web akışı backend'de kalsın, app göstermesin).
- `startPurchase(package:)` (519+) → `SBStoreKitManager.purchase()` çağıracak şekilde yeniden yaz.
- Satın alma sırasında buton `isLoading`, başarıda toast + bakiye refresh, hata/iptalde kullanıcı dostu Türkçe mesaj.
- En alta **"Satın Almalarımı Geri Yükle"** butonu ekle (restore).
- Fiyatları StoreKit `Product.displayPrice`'tan göster (App Store'un yerelleştirilmiş fiyatı), backend fiyatından değil.
- "Öne çıkan" rozet mantığı (`isBestValue = package.coin >= 100`, ~245) coin/fiyat oranına göre düzelt veya backend `featured` alanından al.

### 1.5 Info.plist / yetenekler
- Xcode target'ta **In-App Purchase capability** ekli olmalı (`App/SourceBase.xcodeproj`). StoreKit framework otomatik linklenir.
- Local test için `App/SourceBase/` altına `Products.storekit` configuration file (opsiyonel ama önerilir; sandbox öncesi simülatörde test).

### 1.6 Kabul kriteri
- iOS'ta hiçbir harici ödeme linki/tarayıcı açılışı kalmadı.
- Sandbox hesabıyla satın alma → coin bakiyesi artıyor → çift kredilendirme yok.
- Restore butonu var. Pending (Ask to Buy) durumu çökmüyor.

---

## 2. [P0] DİĞER YAYIN ENGELLERİ

### 2.1 Gizlilik & Şartlar linkleri (Apple zorunlu)
- **`RegisterView.swift:210`** — şu an düz metin. Tıklanabilir `Link` yap:
  - **KESİN URL'ler (kullanıcı onayladı):**
    - Gizlilik Politikası → `https://sourcebase.medasi.com.tr/gizlilik`
    - Kullanım Koşulları → `https://sourcebase.medasi.com.tr/kullanim-kosullari`
    - (KVKK aydınlatma metni gerekirse: `https://sourcebase.medasi.com.tr/kvkk`)
  - Sonnet bunları tek yerde sabit tut: yeni `SBLegalLinks` enum (`privacyURL`, `termsURL`, opsiyonel `kvkkURL`). Aynı URL'leri App Store Connect "App Privacy" → Privacy Policy URL alanına da gir.
- **`SettingsView.swift`** — Ayarlar içinde "Gizlilik Politikası", "Kullanım Şartları" satırları açılır link olmalı (`.profileMenu(.privacySupport)` rotasının gerçekten linkleri gösterdiğini doğrula).
- Login/StoreView altına da en az bir "Şartlar/Gizlilik" erişimi App Store için iyi olur.

### 2.2 Hesap silme & çıkış (Apple zorunlu — backend hazır)
- `ProfileMenuDetailView.swift:381-398` hesap silme UI + `requestAccountDeletion()` (421) bağlı, backend gerçek (`request_account_deletion`). 
- **Yapılacak:** Silme akışını net onay diyaloglu yap ("Bu işlem geri alınamaz"), başarıda oturumu kapatıp login'e at, kullanıcıya 30 gün içinde silineceğini bildir. Çıkış (`signOut`) zaten çalışıyor — onay diyaloğu var, koru.

### 2.3 PDF içerik kesilmesi → Bölüm 8'de detaylı (P0 çıktı kalitesi).

### 2.4 MedasiChat klavye çakışması (açılış ekranı)
- **`CentralAIView.swift:226-266`** `inputArea` `.safeAreaInset(edge:.bottom)` içinde değil; klavye açılınca çentikli cihazlarda input'u örter.
- **Fix:** Ana yapıyı `messagesList` + `inputArea` olacak şekilde, `inputArea`'yı `.safeAreaInset(edge:.bottom)` ile yerleştir; ScrollView'a `.scrollDismissesKeyboard(.interactively)` ekle; `@FocusState` ile gönderim sonrası odak yönetimi.

### 2.5 iPad desteği — KARAR: iPad + iPhone ikisi de desteklenecek (Option B)
- `TARGETED_DEVICE_FAMILY = 1,2` kalsın (iPhone + iPad). Info.plist iPad yön listesi korunur.
- **Gereken iş — geniş ekran düzeni (tüm ana ekranlar):** İçerik şu an `maxWidth: .infinity` ile iPad'de aşırı geniş gerilir (mesaj balonları, kartlar, formlar okunaksız uzar).
  - **Okunabilir kolon sınırı:** Ana içerik bloklarına `frame(maxWidth: <≈680-760>)` + ortala. Yeni yardımcı: `SBReadableContainer` (veya `.sbReadableWidth()` modifier) ekle ve tüm ScrollView içeriklerine uygula (Drive, BaseForce, SourceLab, Profile, Auth formları, MedasiChat mesaj listesi + input).
  - **MedasiChat:** balonlar iPad'de ekranı kaplamasın — bubble `maxWidth` (örn 560) + okunabilir kolon.
  - **Tablet grid:** Drive/BaseForce/SourceLab kart grid'leri iPad'de tek sütun yerine adaptif kolon (`LazyVGrid` `GridItem(.adaptive(minimum: ~320))`) ile 2 sütun kullanabilir (opsiyonel iyileştirme).
  - **NavigationStack** iPad'de de çalışır; `NavigationSplitView`'a geçmek ZORUNLU değil (bu sürümde stack yeterli, riski düşük tut).
- **Test:** iPad portrait + landscape, çoklu görev (Split View) yarı genişlikte layout bozulmuyor; tab bar ortalı/dengeli; klavye formları örtmüyor.

### 2.6 Launch screen (P2 — cila)
- `Info.plist` `UILaunchScreen` boş dict → ilk açılışta düz (beyaz) ekran. Çalışır, App Store engeli değil; ama premium hissi zedeler.
- **Fix (opsiyonel):** Basit markalı launch screen — `SBColors.page`/`pageGradient` zemini + ortada SourceBase logosu/wordmark. `WarmLaunchView` (zaten var) ile karıştırma; bu, sistemin gösterdiği statik launch ekranı (animasyon/kod yok, sadece storyboard/asset). Asset yoksa en azından arka plan rengini marka zeminine çek.

---

## 3. [P1] TASARIM SİSTEMİ — GENEL TUTARLILIK

> Token mimarisi sağlam (`SBColors`, `SBTypography` semantik text-style kullanıyor → **Dynamic Type otomatik ölçekleniyor**, bu iyi haber). Sorun: bazı ekranlarda hardcoded RGB ve sabit ikon boyutları.

### 3.1 Hardcoded renkleri token'a çek
Yeni token gerekiyorsa `SBColors`'a ekle, sonra tüm kullanımları değiştir:
- `SBColors.cyan` zaten var (`SBColors.swift:20`) ama bazı yerlerde elle RGB yazılmış, üstelik değerleri tutarsız:
  - `DriveHomeView.swift:152-156` — hardcoded mavi-mor gradient → `SBColors.primaryGradient`/`brandGradient` veya yeni `SBColors.heroWash`.
  - `FileDetailView.swift:302`, `CollectionsView.swift:97,436,443` — elle cyan RGB → `SBColors.cyan`.
  - `BaseForceHomeView.swift:474` ve `ResultView.swift:404` — `.question` için hardcoded cyan → yeni `SBColors.questionTint` (tek kaynak) yap.
  - `PodcastView.swift:11` ve `SourceLabHomeView.swift:157` — hardcoded mor → `SBColors.purple`.
- Köşe yarıçaplarını standartlaştır: yeni `SBRadius` enum (`sm=4, md=10, lg=14, card=18, xl=24`) ekle, dağınık `cornerRadius:` sabitlerini buna bağla. (Skill `SourceBaseRadius` hedefi.)

### 3.2 Sabit ikon boyutları
- `.font(.system(size: N))` ikonlar Dynamic Type'a tepki vermiyor (ExamMorningView:65, ClinicalView:114, SourceLabHomeView:65/203, SourceLabToolFlowView:80, CentralAIView:85 vb.). Kritik değil; istenirse `.imageScale` veya `@ScaledMetric` ile büyük metin desteği. **P2'ye bırakılabilir.**

### 3.3 Dokunma hedefleri
- Menü/elips butonlarını 44×44 pt'ye sabitle (HIG): `FolderView.swift:364-370` (44) vs `CollectionsView.swift:299-303` (32) tutarsız → hepsi 44.

### 3.4 Erişilebilirlik (genel kural — TÜM ekranlar)
Apple inceleme + VoiceOver için, tüm dokunulabilir öğelere `.accessibilityLabel` + gerektiğinde `.accessibilityHint`, dekoratif ikonlara `.accessibilityHidden(true)`. Aşağıda ekran bazında işaretli. Bu, toplu bir geçişle yapılmalı.

---

## 4. EKRAN EKRAN İŞ LİSTESİ

### 4.1 DRIVE
**P1**
- DriveHomeView:152-156 hardcoded gradient → token (3.1).
- Cyan RGB birleştir: FileDetailView:302, CollectionsView:97/436/443 → `SBColors.cyan`.
- Uzun Türkçe metin taşması (iPhone SE): `DriveHomeView:97` hero mesajı, `FolderView:381` tray alt başlığı, `CollectionsView:216` boş durum → `.lineLimit(2)` + `.fixedSize(horizontal:false, vertical:true)`.
- `FolderView:263` checkbox border hardcoded opacity → token.
- `SearchView:201` focus border `lineWidth:1.4` standart dışı → 1/2; `.submitLabel(.search)` + odak temizleme ekle.
- ScrollView'larda alt tab bar (≈88pt) örtmesine karşı içerik altına güvenli boşluk (`.safeAreaInset(edge:.bottom)` veya alt padding) — Drive tüm liste ekranları.
- `CollectionsView` "Üret" butonu (348-358): `previewKind` nil/boş ise sessiz başarısızlık; guard + hata toast.
- `FileDetailView:145-147` "İşlemeyi tekrar dene": `isRetrying` state + buton loading.
- Dekoratif chevron'lara `.accessibilityHidden(true)` (CourseDetailView:330-332 vb.).

**P2**
- CollectionsView "Üret" menü öğelerine çıktı-tipi ikonları; sıralama yönünü etiketle netleştir.
- UploadsView:302-308 progress bar köşe yarıçapı → `SBRadius.sm`; `.draft` durumu için bağlam mesajı.
- FlowLayout spacing tutarlılığı (`.xs`/`.sm` standardı).
- DriveUploadSheet: izin verilen dosya tipleri zaten alt başlıkta belirtiliyor — koru.

### 4.2 BASEFORCE
> Akış mükemmel kurulu: SourcePicker → 5 factory → GenerationProcessing → Result. Token kullanımı temiz. **P0 yok.**

**P1**
- **`ResultView.swift:445-447` `save()` SADECE toast gösteriyor, gerçekten persist ETMİYOR.** "Koleksiyona Kaydet" sessizce başarısız oluyor. → Ya gerçek kaydetmeye bağla (`workspaceStore` üzerinden bir save endpoint'i varsa) ya da buton metnini gerçeğe uygun yap ("Üretimler listesinde zaten kayıtlı" + butonu kaldır). **Karar gerekiyor; kullanıcıyı yanıltan buton kalmamalı.**
- `ResultView:52-75` boş `contentText` durumu: `emptyContentCard` gösteriliyor ama backend boş dönerse net log/uyarı yok; edge-case testi.
- Erişilebilirlik etiketleri: `BaseForceHomeView` factoryRow (234-284), `QueueView` jobRow (277-320), `GenerationProcessingView` adım listesi (234-256), `ResultView` quickAction (286-333).
- `SourcePickerView` arama TextField'ına `.textInputAutocapitalization(.never)` + uygun klavye.

**P2**
- `BaseForceHomeView:474`/`ResultView:404` question cyan → `SBColors.questionTint` (3.1).
- QuestionFactory/SummaryFactory sourceChip VStack uzun dosya boyutunda taşma → `.fixedSize`.
- AlgorithmFactory segmentButton (410-411) uzun Türkçe etiket SE'de 3 satıra düşebilir → test/`.lineLimit`.
- GenerationProcessing animasyon süresi hardcoded sleep (286-291) → sabit/parametre.
- Generate butonlarına `SBHaptics` dokunsal geri bildirim (MainTabView:90 pattern).

### 4.3 SOURCELAB
> 6 aracın hepsi **gerçek ve fonksiyonel** (placeholder/coming-soon YOK), rotalar bağlı. **P0 yok.** Apple "eksik özellik" reddi riski yok.

**P1**
- PodcastView:11 ve SourceLabHomeView:157 hardcoded mor → `SBColors.purple` (3.1).
- Araç kartlarına, adım başlık dairelerine (ExamMorning:352, Clinical:385), kontrol seçenek butonlarına (SourceLabToolFlowView:154) erişilebilirlik etiketleri.

**P2**
- Sabit ikon font boyutları (3.2).
- Generate butonlarına haptik.
- Yükleme için makul timeout + kullanıcı dostu hata (ExamMorning/Clinical `loadWorkspace`).

### 4.4 MEDASICHAT (CentralAI) — AÇILIŞ EKRANI
> Sohbet **gerçek**: `sendCentralAIMessage()` → `DriveAPI.centralAiChat()` canlı edge function. Gönder→cevap döngüsü, hata yönetimi, boş durum, auto-scroll çalışıyor. Sahte/echo DEĞİL. **P0 yok** (klavye hariç — 2.4'te).

**P1**
- Klavye çakışması → **2.4** (P0 olarak işaretlendi, açılış ekranı olduğu için).
- Erişilebilirlik: TextField (231) ve gönder butonu (244) etiketsiz; chat bubble'larına (75-129) `.accessibilityElement(children:.combine)` + "Asistan/Senin mesajın" etiketi; bağlam dosya chip'leri (166-182) ve öneri chip'leri (207-222) etiket.

**P2**
- Kullanıcı mesaj zaman damgası `.white.opacity(0.7)` (122) → token.
- Öneri chip'lerine basış animasyonu (Pow `.pressEffect`/scale); disabled iken grayscale.
- AI ikonu `book.closed` (85) → `sparkles`/`wand.and.stars` (AI algısı).
- API çağrısına makul timeout (15-30s) + donmuş spinner koruması.

### 4.5 PROFILE / AUTH
**P0** → 1.x (Store), 2.1 (linkler), 2.2 (hesap silme/çıkış — bağlama/onay).

**P1**
- Auth formlarında autofill/klavye: tüm e-posta alanlarına `.textContentType(.emailAddress)` + `.keyboardType(.emailAddress)`; şifre alanlarına `.textContentType(.password)` (login) / `.newPassword` (register). (LoginView:94/122, RegisterView:106/155, ForgotPasswordView:80 vb.)
- Şifre görünürlük toggle ikonuna erişilebilirlik etiketi (LoginView:130-136, RegisterView:165-173).
- Tüm form alanlarına `.accessibilityLabel`/`.hint` (Login, Register, ProfileSetup, VerifyEmail 6 OTP alanı).
- ProfileSetup üniversite autocomplete `.prefix(6)` (90) — 7+ üniversite seçilemiyor → scrollable liste veya limit artır; 0 sonuçta "Üniversite bulunamadı" boş durumu.
- VerifyEmail OTP timer (224-230) app arka plana alınınca bozulabilir → `Date` tabanlı hesap (kalan = hedef tarih - now) ya da geri-plan dayanıklı sayaç.

**P2**
- ProfileSetup departman listesi hardcoded 3 değer (11) → "Diğer" ekle veya backend kataloğu.
- ProfileView wallet fallback 0 (497-509) yanıltıcı olabilir → "bakiye doğrulanamadı" uyarısı.
- Form alanı sabit `height:52`/`cornerRadius:12` Dynamic Type 200%'de test.

### Auth akışı doğrulaması (denetimde OK çıktı, koru)
Login→(verify)→profileSetup→Drive; Register→verify; Forgot/Reset; SignOut hepsi çalışıyor. Reset-password'ün e-posta linkinden `ResetPasswordView`'a nasıl yönlendiğini (deep link) bir kez gerçek cihazda doğrula.

---

## 5. [P1] BACKEND DAYANIKLILIK
> Tüm özellikler gerçek Supabase'e gidiyor; sadece public anon key gömülü (güvenli, HTTPS). Force-unwrap/`try!` yok, JSON parse savunmacı. Aşağıdakiler güvenilirlik iyileştirmeleri.

- **Generation 120s timeout** (`DriveRepository waitForGeneratedContent`, ~343): 60×2s. Sunucu tarafında (`sourcebase/services/job-processor.ts`) iç timeout/poll sabiti YOK — süre tamamen AI sağlayıcı gecikmesine bağlı (Vertex/OpenAI/Anthropic; premium reasoning modelleri daha yavaş olabilir). Ağır işlerde (infographic, clinical, podcast) >120s mümkün. **Öneri:** app timeout'unu 180s'ye çıkar VEYA timeout'ta "üretim arka planda sürüyor, Kuyruk'tan takip et" mesajı göster (job zaten backend'de devam ediyor, iş kaybolmuyor).
- **Sessiz hatalar:** `ProfileRepository.loadWalletBalanceFromEntitlements` (~159) ve `loadProfileRow` (~138) `catch { return nil/0 }` — ağ hatası bakiyeyi 0 gösterir. En azından log + (mümkünse) UI'da "bakiye doğrulanamadı".
- **Edge function invoke timeout** (`DriveAPI.invoke`, ~48): varsayılan 600s; ağ kopmasında uzun bekleme. Mümkünse `Task` timeout sarmalı.
- **Store ürün tablosu 4 farklı şema deniyor** (`StoreRepository`, 40-68) — backend ile tek yetkili tablo/şemayı netleştir, sadeleştir.
- **Status parse toleransı** (`SourceBaseWorkspaceStore` ~632): bilinmeyen status → `.running` varsayılıyor; bilinmeyen status loglansın (kontrat kayması erken yakalanır).
- **CentralAI cevap alanı** (~741-757) 5 alan adı deniyor — backend kontratını sabitle.

**Güvenlik:** Service-role key/şifre/private key YOK; anon key public ve güvenli. RLS politikalarının Supabase'de `profiles`, `wallet_entitlements`, `store_products` üzerinde aktif olduğunu **doğrula** (app backend RLS'ine güveniyor). `print(...)` ile token loglanmıyor — koru.

---

## 6. [P2] CİLA (zaman kalırsa)
- Liste yüklemelerinde Shimmer skeleton (Drive kartları, üretim bekleme) — Shimmer zaten kurulu.
- Pow ile kart basış/başarı mikro-etkileşimleri (abartısız).
- Boş/hata/yükleme durumlarının görsel tutarlılığı (`SBEmptyState`/`SBLoadingState`/`SBErrorState` her yerde kullanılıyor — eksikleri tamamla).
- Reduce Motion'a saygı (SBMotion içinde kontrol).

---

## 7. PDF / ÇIKTI ŞABLONLARI — TAM YENİDEN YAZIM (P0 kalite)

**Mevcut sorun (`SBStudyExportService.swift`):**
- Tek `context.beginPage()` (25-28) — **çok sayfa YOK**.
- `draw(...)` döngüsünde `if y + height > rect.maxY { break }` (101) — **bir sayfayı aşan içerik tamamen kesiliyor/kayboluyor**. Uzun flashcard/özet setleri eksik PDF üretir. Bu premium çıktı vaadini doğrudan bozar.
- Tablo PDF'te render edilmiyor (sadece `exportText`'te düz metin satırı).
- Çizim ham, satır-satır; tipografi/boşluk zayıf; watermark üst köşede başlıkla çakışabilir.

**Yapılacak — `SBStudyExportService` yeniden yazımı:**
1. **Çok sayfalı render:** `y` `rect.maxY`'yi aşınca `break` yerine `context.beginPage()` + sayfa başına header/footer + `y = rect.minY` reset. İçerik bitene kadar sayfa aç.
2. **Yapısal çizim:** `exportText` üzerinden değil, doğrudan `output.studyTemplateContent` (summary, sections[].title/items[], table.headers/rows) üzerinden çiz. Her bölüm için: başlık (headingAttributes) → madde işaretli items (bodyAttributes, asılı girinti).
3. **Tablo render:** `template.table` varsa gerçek grid çiz — sütun genişlikleri içeriğe göre, başlık satırı dolgulu (`SBColors.selectedBlue`), hücre kenarlıkları (hairline), satır taşarsa sayfa kır.
4. **Sayfa kromu:** her sayfada üstte "Medasi SourceBase" + başlık (ilk sayfa büyük), altta sayfa numarası ("s. n / toplam") ve ince çizgi. Watermark'ı (MEDASI) çakışmayacak konuma (sağ-alt veya çapraz açık opaklık) al.
5. **Tipografi:** başlık 24/bold, bölüm 15/semibold (marka mavisi), gövde 11-12/regular, satır aralığı paragraph style ile. Türkçe karakter zaten destekli (sistem fontu).
6. **Uzun başlık/dosya adı:** dosya adı temizleme (10-13) korunur; başlık çok satıra sığsın (`boundingRect` ile yükseklik).
7. **Görsel paritesi:** PDF, uygulamadaki `GeneratedOutputStudyView` (728 satır) ile aynı bölüm sırası ve adlandırmayı izlesin (kullanıcı ekranda gördüğünü PDF'te görsün).

**Kabul kriteri:** 50+ flashcard / uzun özet / 10+ satır tablo içeren çıktı → hiçbir içerik kaybı olmadan çok sayfalı, başlıklı/numaralı, tablolu, hizalı PDF üretir. Her üretim tipi (flashcard, question, summary, algorithm, comparison, podcast script, infographic notu, mindmap, plan) için bir örnek elle göz kontrolü.

**Paylaşım/dışa aktarım:** `GeneratedOutputStudyView` içindeki export tetikleyicisinin `ShareLink`/`UIActivityViewController` ile PDF URL'ini paylaştığını ve hata durumunu kullanıcıya gösterdiğini doğrula.

---

## 8. APP STORE CONNECT — SUBMISSION CHECKLIST

> API anahtarı kullanıcıda: Issuer ID + Key ID + `~/Downloads/AuthKey_72UC3GBH86.p8`. Bu anahtar **App Store Connect API** içindir: build upload (Transporter/`xcrun altool`/`notarytool`) ve IAP/metadata otomasyonu. `.p8` gizli — repo'ya KOYMA, paylaşma; sızarsa App Store Connect → Users and Access → Integrations'tan revoke et.

### 8.1 İmzalama & build (App/SourceBase.xcodeproj)
- `DEVELOPMENT_TEAM` boş geliyor → kullanıcının Team'i Signing & Capabilities'te seçilmeli.
- `MARKETING_VERSION` (örn 1.0.0) ve `CURRENT_PROJECT_VERSION` (build no) ayarla; her yüklemede build no artmalı.
- Bundle ID `tr.com.medasi.sourcebase` App Store Connect kaydıyla eşleşiyor (mevcut).
- **In-App Purchase capability** ekle (Bölüm 1.5).
- Archive → Validate → Upload (Xcode Organizer veya API key ile `altool`).

### 8.2 IAP ürünleri
- Coin paketleri **Consumable** olarak oluştur, Product ID'leri app/backend ile eşleştir (1.2).
- Her ürüne lokalize ad/açıklama, fiyat tier.
- İlk gönderimde IAP'ler build ile birlikte "Submit for Review" — IAP review'dan geçmeden satılamaz.
- En az 1 sandbox test hesabı oluştur (Users and Access → Sandbox).

### 8.3 Privacy & uyumluluk
- Info.plist: `ITSAppUsesNonExemptEncryption=false` mevcut (TLS dışı kripto yok) — koru.
- **App Privacy "nutrition labels"** doldur: toplanan veri = e-posta, isim, fakülte/bölüm/sınıf, dosya metadata, üretim geçmişi, cüzdan. İzleme yok.
- Privacy Policy URL (zorunlu) + (varsa) Terms URL App Store Connect metadata + uygulama içi link (2.1) ile aynı.
- Hesap silme akışı app içinde mevcut olmalı (var — 2.2) ve review notuna nasıl ulaşılacağı yazılmalı.

### 8.4 Metadata & görseller
- Uygulama adı, alt başlık, açıklama (Türkçe; tıp öğrencisi/çalışma materyali konumlandırması), anahtar kelimeler.
- **Screenshots:** 6.7" (zorunlu) + 6.5"/5.5" gerekiyorsa. Önerilen ekranlar: MedasiChat, Drive, BaseForce üretim, SourceLab, bir Result/PDF. (Gerçek cihaz/simülatör; placeholder olmasın.)
- App Icon zaten var (`AppIcon1024.png`).
- **Review notları:** test kullanıcı adı/şifre (uygulama login zorunlu), IAP sandbox bilgisi, "yapay zeka üretimi backend'de gerçekleşir" notu.
- Yaş derecelendirme anketi, kategori (Education), telif/haklar.
- Export Compliance: `ITSAppUsesNonExemptEncryption=false` → ek yok.

---

## 9. BUILD & QA CHECKLIST (yüklemeden önce)
- [ ] `swift build` (SourceBaseiOS + SourceBaseBackend) hatasız; IAP eklenince paket çözümü (`Package.resolved`) güncel.
- [ ] Xcode'da release archive derlenir (warning'ler gözden geçirildi).
- [ ] iPhone SE (375pt) + iPhone 15 Pro Max'te manuel tur: tüm 5 tab + her alt ekran açılıyor, tab bar içerik örtmüyor, klavye formları/sohbeti örtmüyor.
- [ ] Türkçe uzun metinler taşmıyor/kesilmiyor.
- [ ] Dynamic Type büyük boyutta okunur (typography ölçekleniyor).
- [ ] Light mode birincil; dark mode bozuk değil (appearance preference mevcut).
- [ ] Gerçek hesap: login → upload → generate → result → PDF export uçtan uca; çıktıda içerik kaybı yok.
- [ ] IAP sandbox satın alma → coin artıyor, çift kredilendirme yok, restore çalışıyor.
- [ ] Hesap silme + çıkış + şifre sıfırlama gerçek cihazda.
- [ ] Offline'da çökmüyor, kullanıcı dostu hata.
- [ ] Var olan testler: `SourceBaseiOSTests` (UploadAndOutput) + `SourceBaseBackendTests` (Auth, Drive) geçiyor.
- [ ] iPad portrait + landscape + Split View: içerik okunabilir kolonda (aşırı gerilmiyor), kart grid'leri ve formlar düzgün, MedasiChat balonları ekranı kaplamıyor.
- [ ] İlk açılış ekranı (launch screen) en azından marka zemininde, çıplak beyaz değil.

---

## 10. SONNET 4.6 İÇİN UYGULAMA SIRASI (önerilen)
1. **IAP** (Bölüm 1) — en uzun ve backend bağımlı; erken başla, backend kontratını paralel netleştir.
2. **P0 hızlı engeller** (2.1 linkler, 2.2 hesap silme bağla, 2.4 chat klavye).
3. **PDF yeniden yazım** (Bölüm 7) — bağımsız, paralel ilerleyebilir.
4. **Tasarım sistemi geneli** (Bölüm 3: token, radius, dokunma hedefi, toplu erişilebilirlik).
5. **Ekran P1'leri** (Bölüm 4) — Drive, BaseForce (özellikle ResultView.save kararı), SourceLab, Profile/Auth.
6. **Backend dayanıklılık** (Bölüm 5) — backend ekibiyle eşgüdümlü.
7. **P2 cila** (Bölüm 6) — zaman kalırsa.
8. **Build + ASC submission** (Bölüm 8-9) — kullanıcı ile birlikte.

### Kararlar — durum (2026-06-03, sunucu incelemesi sonrası)
- ✅ **Backend redeem:** Çözüldü/netleşti. `praticase-storekit-verify` (JWS doğrulama) + `payment_entitlement_webhook` → `grant_store_product` (kredilendirme) desenleri HAZIR; sourcebase'e `redeem_appstore_purchase` action'ı bunları aynalayarak eklenecek (Bölüm 1.3). Coin ekonomisi de teyitli (Bölüm 1.2).
- ✅ **Generation timeout:** Backend'de iç timeout yok; AI gecikmesine bağlı. Karar: app timeout 180s + "arka planda sürüyor" mesajı (Bölüm 5).
- ✅ **TERMS_URL / PRIVACY_URL:** Kullanıcı onayladı → `/gizlilik` + `/kullanim-kosullari` (Bölüm 2.1).
- ✅ **iPad:** iPad + iPhone ikisi de desteklenecek (Option B). Geniş ekran düzeni işi Bölüm 2.5'te.
- ⏳ **`ResultView.save()`** (`ResultView.swift:445`): sahte toast; gerçek kaydetme endpoint'i yok (backend'de "save output" aksiyonu görülmedi — üretimler zaten `create_generated_output` ile kayıtlı). **Varsayılan karar:** butonu "Üretimler listesinde kayıtlı" bilgisine çevir veya kaldır. (Düşük öncelik, tek açık kalan ürün kararı.)
