# Gemini Bulut ile SourceBase Repo Haritasini Kullanma Rehberi - 2026-05-16

Bu rehber, masaustundeki SourceBase repo dosyalarini Gemini web / Gemini Cloud tarafinda kullanip baska bir ajana dogru kodu buldurmak ve kontrollu degisiklik yaptirmak icin hazirlandi.

## Hazir Dosyalar

Masaustunde kullanacagin iki ana dosya var:

- `SourceBase-Repo-Haritasi-2026-05-16.md`
  - Ilk yuklenecek dosya.
  - Proje mimarisi, dosya konumlari, hangi is icin hangi dosyaya bakilacagi ve dikkat notlarini anlatir.

- `SourceBase-Repomix-2026-05-16.md`
  - Ikinci yuklenecek dosya.
  - Kodun sikistirilmis, ajan-dostu paketidir.
  - Gemini repo haritasindan sonra daha derin kod detayina ihtiyac duyarsa bunu kullanir.

En iyi kullanim sirasi:

1. Once repo haritasini yukle.
2. Gemini'ye haritayi okutup proje hakkinda kisa ozet cikarttir.
3. Sonra gerekiyorsa repomix paketini yukle.
4. Degisiklik istegini cok net hedefle: hangi feature, hangi davranis, hangi dosyalara dokunulabilir.

## Hangi Gemini Ortamini Secmelisin?

### 1. Gemini Web App

Adres: https://gemini.google.com

En pratik yol budur. Dosyalari yukleyip direkt soru sorabilirsin. Google'in resmi yardim sayfasina gore Gemini web, dokumanlari ve kod dosyalarini analiz edebilir; ayni promptta dosya yukleme limitleri ve plan bazli sinirlar vardir. Kod klasoru veya GitHub repository ekleme destegi de vardir, fakat limitler hesaba/plana gore degisebilir.

Bunu kullan:

- Repo haritasini okutmak icin.
- "Bu projede login nerede?", "Upload akisi hangi dosyalarda?", "AI generation nereden basliyor?" gibi sorular icin.
- Kucuk/orta degisiklikleri planlatmak icin.

### 2. Google AI Studio

Adres: https://aistudio.google.com

Gemini API promptlarini denemek icindir. Kod yazdirmak, prompt sablonu test etmek, Files API ile dosya uzerinden deney yapmak icin kullanilabilir. Uygulama icine Gemini API entegre edeceksen daha teknik ortam burasi.

Bunu kullan:

- SourceBase icinde Gemini API kullanilacaksa.
- Prompt/prototype deneyeceksen.
- Dosya yukleyip API davranisini test edeceksen.

### 3. Vertex AI / Google Cloud

Adres: https://console.cloud.google.com/vertex-ai

Kurumsal/production Google Cloud tarafidir. IAM, servis hesaplari, region, kota, logging, billing ve production deployment gerekiyorsa Vertex AI kullanilir.

Bunu kullan:

- SourceBase backend/Edge Function tarafinda Google Cloud Gemini veya Vertex AI ile production entegrasyon yapilacaksa.
- Service account, quota, billing, model secimi, monitoring gerekiyorsa.
- Mevcut repoda zaten Vertex AI servis dosyasi oldugu icin (`supabase/functions/sourcebase/services/vertex-ai.ts`) production AI tarafinda asil bakilacak yer burasidir.

## Gemini Web App ile Adim Adim Kullanim

1. `gemini.google.com` adresini ac.
2. Yeni bir sohbet baslat.
3. Once `SourceBase-Repo-Haritasi-2026-05-16.md` dosyasini yukle.
4. Su promptu yaz:

```text
Bu dosya SourceBase repo haritasi. Once bunu oku ve projeyi 10 maddede ozetle.
Sonra bana su formatta cevap ver:
- Ana teknoloji
- Ana giris dosyalari
- Auth nerede
- Drive/API nerede
- Supabase Edge Function nerede
- AI generation nerede
- Degisiklik yaparken dikkat edilecek noktalar

Kod degisikligi onermeden once dosya konumlarini dogrula.
```

5. Gemini ozet verdikten sonra gerekiyorsa `SourceBase-Repomix-2026-05-16.md` dosyasini yukle.
6. Ikinci prompt:

```text
Simdi repomix paketini de yukledim. Bundan sonra cevap verirken once repo haritasini,
sonra repomix icindeki kod detaylarini referans al.

Bir degisiklik istedigimde:
1. Dokunulacak dosyalari listele.
2. Neden bu dosyalar oldugunu acikla.
3. Mevcut dirty worktree veya ilgisiz degisiklikleri revert etme.
4. Service role key'i Flutter/browser tarafina tasima.
5. Flutter tarafindaki degisikliklerde ilgili UI ve repository/API akisini birlikte kontrol et.
```

## Kod Degisikligi Icin Ana Prompt Sablonu

Gemini'ye degisiklik yaptirirken bunu kullan:

```text
SourceBase repo haritasi ve repomix paketine gore ilerle.

Istedigim degisiklik:
[BURAYA NET ISTEGI YAZ]

Kurallar:
- Once hangi dosyalara dokunacagini soyle.
- Sonra degisiklik planini kisa yaz.
- Mevcut dosya yapisina uygun ilerle.
- Ilgisiz refactor yapma.
- Supabase service role key, secret veya backend-only credential'i Flutter/browser tarafina tasima.
- Eger Edge Function action'i degisirse Flutter `SourceBaseDriveApi` ve `DriveRepository` tarafini da kontrol et.
- Eger UI degisirse responsive/mobile davranisi da dusun.
- Sonunda test/verify icin hangi komutlar calistirilmali soyle.
```

## Soru Sorma Promptlari

### Projede bir yeri buldurmak icin

```text
Repo haritasina gore "[KONU]" hangi dosyalarda?
Bana once en alakali 5 dosyayi ver, sonra her dosyanin rolunu 1 cumleyle acikla.
Kod degisikligi yapma, sadece yer tespiti yap.
```

Ornek:

```text
Repo haritasina gore upload akisi hangi dosyalarda?
Bana once en alakali 5 dosyayi ver, sonra her dosyanin rolunu 1 cumleyle acikla.
Kod degisikligi yapma, sadece yer tespiti yap.
```

### Degisiklik planlatmak icin

```text
Bu istegi SourceBase repo yapisina gore planla:
[ISTEK]

Cevap formati:
- Dokunulacak dosyalar
- Mevcut akis
- Degisiklik plani
- Riskler
- Test/verify adimlari

Henuz kod yazma.
```

### Kod yazdirmak icin

```text
Simdi plandaki degisikligi uygula.
Patch verirken dosya yolunu net yaz.
Sadece gerekli dosyalari degistir.
Mevcut kullanici degisikliklerini geri alma.
```

## SourceBase Icin Hazir Senaryo Promptlari

### Auth degisikligi

```text
SourceBase auth akisini incele. Ana dosyalar:
- `lib/features/auth/data/sourcebase_auth_backend.dart`
- `lib/features/auth/presentation/screens/*`
- `lib/features/auth/presentation/widgets/auth_widgets.dart`
- `lib/app/sourcebase_app.dart`

Istedigim degisiklik: [BURAYA YAZ]
Once dosya bazli etki analizini ver, sonra patch oner.
```

### Drive/upload degisikligi

```text
SourceBase Drive/upload akisini incele. Ana dosyalar:
- `lib/features/drive/data/drive_models.dart`
- `lib/features/drive/data/sourcebase_drive_api.dart`
- `lib/features/drive/data/drive_repository.dart`
- `lib/features/drive/data/drive_upload_service_web.dart`
- `lib/features/drive/presentation/screens/drive_workspace_screen.dart`
- `supabase/functions/sourcebase/index.ts`

Istedigim degisiklik: [BURAYA YAZ]
Flutter client, Edge Function ve DB etkisini birlikte degerlendir.
```

### AI generation degisikligi

```text
SourceBase AI generation akisini incele. Ana dosyalar:
- `lib/features/drive/data/drive_repository.dart`
- `lib/features/drive/data/sourcebase_drive_api.dart`
- `supabase/functions/sourcebase/actions/ai-generation.ts`
- `supabase/functions/sourcebase/services/job-processor.ts`
- `supabase/functions/sourcebase/services/vertex-ai.ts`
- `supabase/migrations/20260516_complete_sourcebase_schema.sql`

Istedigim degisiklik: [BURAYA YAZ]
Job tipi, DB semasi, polling ve UI sonucunu birlikte kontrol et.
```

### UI/theme degisikligi

```text
SourceBase UI/theme yapisini incele. Ana dosyalar:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/design_system/buttons/*`
- `lib/features/drive/presentation/widgets/drive_ui.dart`
- `lib/features/drive/presentation/screens/drive_workspace_screen.dart`

Istedigim degisiklik: [BURAYA YAZ]
Mobil ve desktop layout etkisini de belirt.
```

## Gemini Limitlerine Takilirsa

Gemini yuklenen dosya buyuklugunde veya ayni prompttaki dosya sayisinda limite takilabilir. Resmi yardim sayfasi, buyuk dosyalarda Gemini'nin detaylar arasindaki baglantilari kacirabilecegini de belirtiyor. Bu olursa:

1. Sadece `SourceBase-Repo-Haritasi-2026-05-16.md` ile basla.
2. Repomix dosyasini yukleme; onun yerine ilgili dosya bolumlerini kopyala.
3. Gemini'ye once "hangi dosyalara bakmaliyim?" diye sordur.
4. Sadece o dosyalarin kodunu ver.
5. Buyuk tek dosyalarda hedef class/widget adini belirt:
   - `baseforce_screen.dart`
   - `source_lab_screen.dart`
   - `central_ai_screen.dart`

Bolerek ilerleme promptu:

```text
Repomix dosyasi buyuk oldugu icin once sadece repo haritasina gore ilerle.
Bu is icin gereken en alakali dosyalari soyle.
Ben sana sonra sadece o dosyalarin icerigini verecegim.
```

## Gemini'den Alacagin Cevabi Kontrol Etme

Gemini bir patch veya kod onerirse sunlari kontrol et:

- Dosya yolu repo haritasindaki gercek yolla ayni mi?
- Flutter tarafinda `SourceBaseDriveApi` action adi Edge Function `switch` icinde var mi?
- DB tablo/kolon adi migration ile uyumlu mu?
- Browser/Flutter koduna secret/service role key koymamis mi?
- Buyuk UI dosyalarinda ilgisiz refactor yapmamis mi?
- `GeneratedKind` veya action eklediyse hem enum, hem repository mapping, hem Edge Function tarafini tamamlamis mi?
- Deploy degisikligi varsa `Dockerfile`, `nginx.conf`, Coolify env isimleri birbiriyle tutarli mi?

## En Guvenli Calisma Sekli

1. Gemini'ye once sadece analiz yaptir.
2. Planini al.
3. Dosya listesini kontrol et.
4. Sonra patch iste.
5. Patch'i Codex veya lokal editor ile uygula.
6. Flutter/Deno kontrollerini calistir.

Onerilen kontrol komutlari:

```bash
flutter analyze
flutter test
deno check supabase/functions/sourcebase/index.ts
deno check supabase/functions/ai-services/index.ts
```

Bu projede Flutter SDK yolu lokal makinede farkli olabilir. Daha once kullanilan lokal yollar varsa onlari tercih et.

## Kisa Tek Prompt

Acele durumda Gemini'ye su tek promptla baslayabilirsin:

```text
Bu SourceBase repo haritasini oku. Bu proje Flutter + Supabase Edge Functions + Vertex AI yapisinda.
Ben sana degisiklik istedigimde once ilgili dosyalari bul, sonra plan yap, sonra patch oner.
Ilgisiz dosyalari degistirme, mevcut dirty worktree'yi geri alma, service role key'i Flutter/browser tarafina tasima.
Ana girisler: `lib/main.dart`, `lib/app/sourcebase_app.dart`, `lib/features/drive/data/sourcebase_drive_api.dart`, `lib/features/drive/data/drive_repository.dart`, `supabase/functions/sourcebase/index.ts`.
```

## Resmi Kaynaklar

- Gemini web dosya yukleme ve analiz: https://support.google.com/gemini/answer/14903178
- Gemini API Files API: https://ai.google.dev/gemini-api/docs/files
- Vertex AI Gemini dokumantasyonu: https://cloud.google.com/vertex-ai/generative-ai/docs
