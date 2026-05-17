# SourceBase Repo Haritasi - 2026-05-16

Bu dosya, bu repo herhangi bir ajana verildiginde "hangi kod nerede, neyi degistirmek icin nereye bakmali" sorusunu hizli cevaplamak icin hazirlandi. Yaninda uretilen `SourceBase-Repomix-2026-05-16.md` dosyasi ise kodun sikistirilmis, ajan-dostu paketidir.

## Kisa Ozet

- Proje adi: `sourcebase`
- Urun: MedAsi ekosistemi icin Flutter tabanli SourceBase flashcard / kaynak / AI uretim uygulamasi.
- Ana teknoloji: Flutter/Dart, Supabase Auth, Supabase Edge Functions (Deno/TypeScript), Supabase SQL migrations, Google Cloud Storage signed upload, Vertex AI servisleri.
- Ana uygulama girisi: `lib/main.dart`
- Flutter app/router: `lib/app/sourcebase_app.dart`
- Auth backend: `lib/features/auth/data/sourcebase_auth_backend.dart`
- Drive/API istemcisi: `lib/features/drive/data/sourcebase_drive_api.dart`
- Drive veri cevirme ve repository: `lib/features/drive/data/drive_repository.dart`
- Ana workspace ekrani: `lib/features/drive/presentation/screens/drive_workspace_screen.dart`
- Supabase ana Edge Function: `supabase/functions/sourcebase/index.ts`
- AI generation actionlari: `supabase/functions/sourcebase/actions/ai-generation.ts`
- Ana DB semasi: `supabase/migrations/20260515_create_sourcebase_drive_schema.sql` ve `supabase/migrations/20260516_complete_sourcebase_schema.sql`
- Docker web deploy: `Dockerfile` + `nginx.conf`

## Mimari Akis

1. `lib/main.dart`
   - Flutter binding ve semantics acilir.
   - `SourceBaseAuthBackend.initialize()` ile Supabase configure edilir.
   - `SourceBaseApp` baslatilir.

2. `lib/app/sourcebase_app.dart`
   - `MaterialApp` route tablosunu kurar.
   - Ilk route auth durumuna gore secilir:
     - Supabase yoksa veya user yoksa `/login`
     - SourceBase profil bilgisi eksikse `/profile-setup`
     - Hazirsa `/drive`

3. Flutter client -> Supabase Edge Function
   - Flutter tarafinda `SourceBaseDriveApi.invoke(action, payload)` kullanilir.
   - Bu method Supabase Functions uzerinden `sourcebase` edge function'a `{ action, payload }` body gonderir.
   - Edge function `supabase/functions/sourcebase/index.ts` icinde `switch (action)` ile ilgili islemi calistirir.

4. Upload akisi
   - Flutter file picker: `lib/features/drive/data/drive_upload_service_web.dart`
   - Draft/payload modelleri: `drive_models.dart`, `drive_upload_payload.dart`
   - Signed URL olusturma: Edge action `create_upload_session`
   - GCS'ye PUT upload: Flutter upload service
   - DB kaydi: Edge action `complete_upload`
   - Kullandigi tablo: `sourcebase.drive_files`

5. AI uretim akisi
   - Flutter'da `DriveRepository.createGeneratedOutput(...)`
   - `GeneratedKind` -> job type map'i `drive_repository.dart` icinde.
   - Edge action `create_generation_job`
   - Job processor: `supabase/functions/sourcebase/services/job-processor.ts`
   - Vertex AI client: `supabase/functions/sourcebase/services/vertex-ai.ts`
   - Extraction: `supabase/functions/sourcebase/services/extraction.ts`
   - Job tablosu: `sourcebase.generated_jobs`

## Dizin Haritasi

### Kok Dosyalar

- `README.md`: Urun/deploy sinirlari, Coolify ve auth boundary aciklamasi.
- `pubspec.yaml`: Flutter proje metadata, dependency listesi ve asset kayitlari. Ana dependencyler: `supabase_flutter`, `responsive_builder`.
- `pubspec.lock`: Kilitlenmis Dart/Flutter paket versiyonlari.
- `analysis_options.yaml`: Flutter lint ayarlari.
- `.env.example`: Beklenen ortam degiskenleri icin ornek.
- `Dockerfile`: Flutter web build alip Nginx ile servis eden multi-stage Docker build.
- `nginx.conf`: Flutter web icin Nginx route/static ayarlari.
- `deploy.sh`, `deploy.py`, `check_deployment.py`, `test_build.sh`: Deploy/build kontrol yardimcilari.
- `README_DEPLOYMENT.md`, `COOLIFY_*`, `DEPLOYMENT_*`, `PRODUCTION_READY.md`: Coolify ve production notlari.
- `SourceBase Plani.md`, `SourceBase-iPhone14-Ekran-Takip-Listesi.md`, `plans/*.md`: Urun, tasarim ve production plan dokumanlari.

### Flutter App - `lib/`

- `lib/main.dart`: Uygulama girisi.
- `lib/auth_backend.dart`: Eski/yardimci auth backend dosyasi; aktif auth kodu feature altindaki `sourcebase_auth_backend.dart`.
- `lib/app/sourcebase_app.dart`: Tema, route listesi, initial route karari.

### Core UI ve Tema

- `lib/core/theme/app_colors.dart`: Global renk paleti.
- `lib/core/theme/app_theme.dart`: Material theme, input/button/card stilleri.
- `lib/core/widgets/sourcebase_brand.dart`: SourceBase logo/mark widgetleri.
- `lib/core/widgets/responsive_layout.dart`: Responsive wrapper/grid/helper widgetleri.
- `lib/core/design_system/design_system.dart`: Design system barrel export.
- `lib/core/design_system/buttons/*.dart`: `SBPrimaryButton`, `SBSecondaryButton`, `SBTextButton`, `SBIconButton`.
- `lib/core/design_system/constants/*.dart`: Spacing/dimension sabitleri.
- `lib/core/design_system/typography/sb_text_styles.dart`: Tipografi stilleri.

### Auth Feature

- `lib/features/auth/data/sourcebase_auth_backend.dart`
  - Supabase init, auth config, sign in/up, Google/Apple OAuth, password reset, profile metadata update.
  - Dart define anahtarlari: `SOURCEBASE_SUPABASE_URL`, `SOURCEBASE_SUPABASE_ANON_KEY`, `SOURCEBASE_PUBLIC_URL`.
  - Kullanici metadata alanlari: `app_code=sourcebase`, `sourcebase_faculty`, `sourcebase_department`, `sourcebase_profile_completed`.

- `lib/features/auth/presentation/screens/login_screen.dart`: Login UI ve auth submit.
- `register_screen.dart`: Kayit UI, signup metadata.
- `forgot_password_screen.dart`: Reset maili akisi.
- `verify_email_screen.dart`: E-posta dogrulama sonrasi ekran.
- `profile_setup_screen.dart`: Faculty/department tamamlama.
- `auth_callback_screen.dart`: OAuth/email callback sonrasi dogru route'a yonlendirme.
- `lib/features/auth/presentation/widgets/auth_widgets.dart`: Auth ekranlarinda kullanilan frame, field, button ve background componentleri.

### Drive Feature

- `lib/features/drive/data/drive_models.dart`
  - Ana UI/veri modelleri: `DriveWorkspaceData`, `DriveCourse`, `DriveSection`, `DriveFile`, `GeneratedOutput`, `UploadTask`, `CollectionBundle`, `DriveUploadDraft`, `GcsUploadSession`.
  - Enumlar: `DriveFileKind`, `DriveItemStatus`, `GeneratedKind`.

- `lib/features/drive/data/sourcebase_drive_api.dart`
  - Edge function istemci sarmalayicisi.
  - Actionlar: `drive_bootstrap`, `create_upload_session`, `complete_upload`, `create_course`, `create_section`, `create_generated_output`, `create_generation_job`, `get_job_status`, `get_generated_content`, `central_ai_chat`.

- `lib/features/drive/data/drive_repository.dart`
  - API response -> UI model mapping.
  - Fallback local data davranislari.
  - AI job polling: `_waitForGeneratedContent`.
  - `GeneratedKind` -> AI job type mapping.

- `drive_upload_payload.dart`: Picked/upload payload veri tipi.
- `drive_upload_service.dart`: Platform conditional export.
- `drive_upload_service_web.dart`: Web file picker ve upload servisi.
- `drive_upload_service_stub.dart`: Web disi stub.
- `seed_drive_data.dart`: Seed/mock drive verileri.

Drive ekranlari:

- `drive_workspace_screen.dart`: Ana shell; nav state, repository load, upload/course/section/generation islemleri.
- `drive_home_screen.dart`: Drive ana sayfa.
- `course_detail_screen.dart`: Course/section/file gorunumu.
- `folder_screen.dart`: Klasor/bolum detaylari.
- `file_detail_screen.dart`: Dosya detay ve generated output kartlari.
- `uploads_screen.dart`: Yukleme durumlari.
- `collections_screen.dart`: Uretilmis output koleksiyonlari.
- `drive_search_screen.dart`: Drive search UI.

Drive ortak widgetleri:

- `drive_ui.dart`: Top bar, file icon, shared cards, generated icon/color helperlari, empty state vb.
- `sourcebase_nav_rail.dart`: Desktop/tablet sol navigasyon.
- `sourcebase_bottom_nav.dart`: Mobil bottom navigation.

### BaseForce Feature

- `lib/features/baseforce/presentation/screens/baseforce_screen.dart`
  - Tek buyuk dosyada BaseForce generator deneyimi.
  - Flashcard, soru, ozet, algoritma, karsilastirma, kuyruk ve sonuc ekranlarini iceren local UI state.
  - Cok sayida private widget ayni dosyada.
  - Bu alanda duzenleme yaptirirken dosyanin buyuk oldugunu soylemek iyi olur; ajan spesifik class/view hedeflemeli.

### Central AI Feature

- `lib/features/central_ai/presentation/screens/central_ai_screen.dart`
  - Merkezi AI chat arayuzu.
  - Drive context dosyalari secilir.
  - `SourceBaseDriveApi.centralAiChat(...)` ile edge function'a gider.
  - Mode enum: tutor, clinic, research, planning.

### SourceLab Feature

- `lib/features/sourcelab/presentation/screens/source_lab_screen.dart`
  - SourceLab home ve arac ekranlari.
  - View enumlari: `SourceLabView`, `_ToolKind`, `_HeroArtKind`.
  - Klinik senaryo, calisma plani, podcast, infografik ve zihin haritasi builder/result UI'lari tek dosyada.

### Profile Feature

- `lib/features/profile/presentation/screens/profile_screen.dart`
  - Profil, wallet panel, settings ve MedasiCoin store UI.
  - Supabase client ile `profiles` ve `store_products` tablolarindan okuma yapar.

### Web/Native Shell

- `web/index.html`, `web/flutter_bootstrap.js`, `web/manifest.json`, `web/icons/*`, `web/favicon.png`: Flutter web shell ve PWA assetleri.
- `android/*`: Android Gradle, manifest, launcher, MainActivity.
- `ios/*`: iOS Runner, Xcode project/workspace, Podfile, AppDelegate/SceneDelegate, app icons/launch assets.

## Supabase Haritasi

### Genel

- Supabase proje config: `supabase/config.toml`
- Deno config/imports: `supabase/deno.json`, `supabase/import_map.json`
- Shared helpers:
  - `supabase/functions/_shared/cors.ts`
  - `supabase/functions/_shared/supabase-client.ts`

### Ana SourceBase Edge Function

- `supabase/functions/sourcebase/index.ts`
  - HTTP POST only.
  - Auth: gelen `authorization` header'i ile Supabase `/auth/v1/user` dogrulama.
  - DB access: service role ile REST endpoint, `accept-profile/content-profile: sourcebase`.
  - Action dispatcher:
    - Drive: `drive_bootstrap`, `create_course`, `create_section`, `create_upload_session`, `complete_upload`, `create_generated_output`
    - AI: `process_file_extraction`, `create_generation_job`, `get_job_status`, `get_generated_content`, `list_user_jobs`, `cancel_job`, `retry_job`, `central_ai_chat`
  - GCS signed upload URL uretimi ayni dosyada: `createGcsV4SignedPutUrl`.

- `supabase/functions/sourcebase/actions/ai-generation.ts`
  - AI job lifecycle actionlari.
  - File extraction tetikleme.
  - Central AI chat.

- `supabase/functions/sourcebase/services/job-processor.ts`
  - `generated_jobs` kaydini isleme, status update, sonuc yazma.

- `supabase/functions/sourcebase/services/vertex-ai.ts`
  - Vertex AI prompt/generation client.

- `supabase/functions/sourcebase/services/extraction.ts`
  - Drive dosyasindan text extraction altyapisi.

- `supabase/functions/sourcebase/types.ts`
  - `SafeError`, record guards, ortak tipler.

- `supabase/functions/sourcebase/validators/content.ts`
  - Icerik validation helperlari.

- `supabase/functions/sourcebase/README.md`, `AI_GENERATION_API.md`, `AI_IMPLEMENTATION_SUMMARY.md`
  - Edge function ve AI implementation dokumantasyonu.

### `ai-services` Edge Function

- `supabase/functions/ai-services/index.ts`
  - Embedding/concept/similarity actionlari.
  - `ai_usage_logs`, `concepts`, `concept_relationships` ve `find_similar_sources_and_cards` RPC ile iliskili.

### Migrations

- `supabase/migrations/20260515_create_sourcebase_drive_schema.sql`
  - Drive odakli temel tablolar: `courses`, `sections`, `drive_files`, `generated_outputs`, `audit_logs`.
  - RLS policy ve indexler.

- `supabase/migrations/20260516_complete_sourcebase_schema.sql`
  - Full SourceBase semasi: `sources`, `decks`, `cards`, `generated_jobs`, `products`, `product_decks`, `purchases`, `entitlements`, `study_sessions`, `study_progress`, `app_memberships`.
  - Marketplace/entitlement/study progress/RLS yapilari.

- `20260516_fix_generated_jobs_ai_schema.sql`
  - `generated_jobs` tablosunu edge function job processor ile uyumlu hale getirir.

- `20260516120012_vector_support.sql`
  - `sources` ve `cards` embedding vector kolon/index destegi.

- `20260516120100_create_find_similar_rpc.sql`
  - Similarity search RPC.

- `20260516120448_automate_embedding_triggers.sql`
  - Embedding automation triggerlari.

- `20260516120617_knowledge_graph_schema.sql`
  - Knowledge graph / concept semasi.

- `MIGRATION_SUMMARY.md`, `QUICK_REFERENCE_SCHEMA.md`, `README_20260516_SCHEMA.md`, `test_20260516_migration.sql`
  - Sema dokumani, hizli referans ve migration testleri.

## DB Tablo Gruplari

- Drive: `sourcebase.courses`, `sourcebase.sections`, `sourcebase.drive_files`, `sourcebase.generated_outputs`, `sourcebase.audit_logs`
- Source/deck/card: `sourcebase.sources`, `sourcebase.decks`, `sourcebase.cards`
- AI jobs: `sourcebase.generated_jobs`
- Marketplace/payment/access: `sourcebase.products`, `sourcebase.product_decks`, `sourcebase.purchases`, `sourcebase.entitlements`
- Study: `sourcebase.study_sessions`, `sourcebase.study_progress`
- Membership/admin: `sourcebase.app_memberships`
- Knowledge/embedding: migrations altindaki vector, concept ve similarity yapilari.

## Ortam Degiskenleri

Flutter build-time:

- `SOURCEBASE_SUPABASE_URL`
- `SOURCEBASE_SUPABASE_ANON_KEY`
- `SOURCEBASE_PUBLIC_URL`

Edge Function runtime:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SOURCEBASE_GCS_BUCKET`
- `SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON`
- `SOURCEBASE_ALLOWED_ORIGIN`
- Vertex AI tarafinda kullanilan project/location/model/service account degiskenleri icin `supabase/functions/sourcebase/AI_IMPLEMENTATION_SUMMARY.md` ve `vertex-ai.ts` kontrol edilmeli.

Deploy/Coolify notu:

- README'de `SOURCEBASE_SUPABASE_PUBLIC_TOKEN` build arg olarak anlatiliyor; Dockerfile ise `SOURCEBASE_SUPABASE_ANON_KEY` bekliyor. Coolify ayarlarinda bu isimlerin eslestigini kontrol ettir.
- Flutter/browser koduna asla service role key koyma.

## Ajanlara Verilecek Hedefli Yonlendirme

Auth degistirilecekse:

- Basla: `lib/features/auth/data/sourcebase_auth_backend.dart`
- UI: `lib/features/auth/presentation/screens/*`
- Shared UI: `lib/features/auth/presentation/widgets/auth_widgets.dart`
- Route karari: `lib/app/sourcebase_app.dart`

Drive veri/model/API degistirilecekse:

- Model: `lib/features/drive/data/drive_models.dart`
- API wrapper: `lib/features/drive/data/sourcebase_drive_api.dart`
- JSON mapping/fallback/polling: `lib/features/drive/data/drive_repository.dart`
- Ana ekran state ve callbackler: `lib/features/drive/presentation/screens/drive_workspace_screen.dart`

Upload degistirilecekse:

- Web picker/upload: `lib/features/drive/data/drive_upload_service_web.dart`
- Upload draft/session modeli: `drive_models.dart`, `drive_upload_payload.dart`
- Signed URL ve DB insert: `supabase/functions/sourcebase/index.ts`
- DB tablo: `sourcebase.drive_files`

AI generation degistirilecekse:

- Flutter trigger/polling: `lib/features/drive/data/drive_repository.dart`
- API action wrapper: `sourcebase_drive_api.dart`
- Edge action: `supabase/functions/sourcebase/actions/ai-generation.ts`
- Job processor: `supabase/functions/sourcebase/services/job-processor.ts`
- Vertex prompt/model: `supabase/functions/sourcebase/services/vertex-ai.ts`
- Sema: `supabase/migrations/20260516_complete_sourcebase_schema.sql` ve fix migration.

Central AI chat degistirilecekse:

- UI/state/context secimi: `lib/features/central_ai/presentation/screens/central_ai_screen.dart`
- Client action: `SourceBaseDriveApi.centralAiChat`
- Edge implementation: `centralAiChat` in `supabase/functions/sourcebase/actions/ai-generation.ts`

Tema/design system degistirilecekse:

- Renkler: `lib/core/theme/app_colors.dart`
- Global theme: `lib/core/theme/app_theme.dart`
- Button componentleri: `lib/core/design_system/buttons/*`
- Drive ortak widgetleri: `lib/features/drive/presentation/widgets/drive_ui.dart`
- Responsive helper: `lib/core/widgets/responsive_layout.dart`

Navigation/shell degistirilecekse:

- App route: `lib/app/sourcebase_app.dart`
- Drive tab/shell state: `drive_workspace_screen.dart`
- Desktop nav: `sourcebase_nav_rail.dart`
- Mobile nav: `sourcebase_bottom_nav.dart`

Deployment degistirilecekse:

- Docker build: `Dockerfile`
- Nginx serving/fallback: `nginx.conf`
- Coolify docs: `README.md`, `README_DEPLOYMENT.md`, `COOLIFY_DEPLOYMENT_GUIDE.md`, `COOLIFY_QUICK_START.md`
- Local checks: `test_build.sh`, `check_deployment.py`

Native platform degistirilecekse:

- Android app id/main activity: `android/app/src/main/kotlin/tr/com/medasi/sourcebase/MainActivity.kt`
- Android manifest/build: `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- iOS runner config: `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner/SceneDelegate.swift`

## Bilinen Dikkat Noktalari

- Worktree dirty durumda; mevcut degisiklikler kullaniciya ait olabilir. Ajanlara "unrelated changes revert etme" diye belirt.
- `supabase/functions` altinda macOS AppleDouble dosyalari (`._*`) gorunuyor. Bunlar kaynak kod degil; editlenmemeli, gerekirse temizlenmeli.
- `baseforce_screen.dart` ve `source_lab_screen.dart` cok buyuk tek-dosya UI'lar. Spesifik class/section hedeflenmeden refactor yaptirma.
- Supabase Edge Function `sourcebase` service role ile DB yazar; browser/Flutter tarafina service role tasinmamali.
- DB REST call'lari `sourcebase` schema profile headerlariyla gidiyor; schema ismi degistirilirse Edge Function da guncellenmeli.
- `DriveRepository.loadWorkspace()` hata yakalayip empty state donuyor; backend hatalari UI'da sessiz kalabilir.
- `GeneratedKind.table` ve `GeneratedKind.mindMap` icin job type su an `null`; repository sadece `generated_outputs` kaydi olusturuyor, AI job baslatmiyor.
- `README.md` ile `Dockerfile` build arg isimleri arasindaki `SOURCEBASE_SUPABASE_PUBLIC_TOKEN` / `SOURCEBASE_SUPABASE_ANON_KEY` farkina dikkat et.
- `lib/auth_backend.dart` ile `lib/features/auth/data/sourcebase_auth_backend.dart` karisabilir; aktif akista feature altindaki dosya kullaniliyor.

## Dosya Envanteri

Kod ve dokuman dosyalari icin ana liste:

```text
.env.example
COOLIFY_BUILD_FIX_SUMMARY.md
COOLIFY_DEPLOYMENT_GUIDE.md
COOLIFY_QUICK_START.md
DEPLOYMENT_CHECKLIST.md
DEPLOYMENT_SUCCESS.md
Dockerfile
PRODUCTION_READY.md
README.md
README_DEPLOYMENT.md
SourceBase Plani.md
SourceBase-iPhone14-Ekran-Takip-Listesi.md
analysis_options.yaml
android/app/build.gradle.kts
android/app/src/debug/AndroidManifest.xml
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/tr/com/medasi/sourcebase/MainActivity.kt
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/values/styles.xml
android/app/src/profile/AndroidManifest.xml
android/build.gradle.kts
android/gradle.properties
android/gradle/wrapper/gradle-wrapper.properties
android/settings.gradle.kts
check_deployment.py
deploy.py
deploy.sh
ios/Flutter/AppFrameworkInfo.plist
ios/Flutter/Debug.xcconfig
ios/Flutter/Release.xcconfig
ios/Podfile
ios/Podfile.lock
ios/Runner.xcodeproj/project.pbxproj
ios/Runner/AppDelegate.swift
ios/Runner/Info.plist
ios/Runner/Runner-Bridging-Header.h
ios/Runner/SceneDelegate.swift
ios/RunnerTests/RunnerTests.swift
lib/app/sourcebase_app.dart
lib/auth_backend.dart
lib/core/design_system/buttons/sb_icon_button.dart
lib/core/design_system/buttons/sb_primary_button.dart
lib/core/design_system/buttons/sb_secondary_button.dart
lib/core/design_system/buttons/sb_text_button.dart
lib/core/design_system/constants/sb_dimensions.dart
lib/core/design_system/constants/sb_spacing.dart
lib/core/design_system/design_system.dart
lib/core/design_system/typography/sb_text_styles.dart
lib/core/theme/app_colors.dart
lib/core/theme/app_theme.dart
lib/core/widgets/responsive_layout.dart
lib/core/widgets/sourcebase_brand.dart
lib/features/auth/data/sourcebase_auth_backend.dart
lib/features/auth/presentation/screens/auth_callback_screen.dart
lib/features/auth/presentation/screens/forgot_password_screen.dart
lib/features/auth/presentation/screens/login_screen.dart
lib/features/auth/presentation/screens/profile_setup_screen.dart
lib/features/auth/presentation/screens/register_screen.dart
lib/features/auth/presentation/screens/verify_email_screen.dart
lib/features/auth/presentation/widgets/auth_widgets.dart
lib/features/baseforce/presentation/screens/baseforce_screen.dart
lib/features/central_ai/presentation/screens/central_ai_screen.dart
lib/features/drive/data/drive_models.dart
lib/features/drive/data/drive_repository.dart
lib/features/drive/data/drive_upload_payload.dart
lib/features/drive/data/drive_upload_service.dart
lib/features/drive/data/drive_upload_service_stub.dart
lib/features/drive/data/drive_upload_service_web.dart
lib/features/drive/data/seed_drive_data.dart
lib/features/drive/data/sourcebase_drive_api.dart
lib/features/drive/presentation/screens/collections_screen.dart
lib/features/drive/presentation/screens/course_detail_screen.dart
lib/features/drive/presentation/screens/drive_home_screen.dart
lib/features/drive/presentation/screens/drive_search_screen.dart
lib/features/drive/presentation/screens/drive_workspace_screen.dart
lib/features/drive/presentation/screens/file_detail_screen.dart
lib/features/drive/presentation/screens/folder_screen.dart
lib/features/drive/presentation/screens/uploads_screen.dart
lib/features/drive/presentation/widgets/drive_ui.dart
lib/features/drive/presentation/widgets/sourcebase_bottom_nav.dart
lib/features/drive/presentation/widgets/sourcebase_nav_rail.dart
lib/features/profile/presentation/screens/profile_screen.dart
lib/features/sourcelab/presentation/screens/source_lab_screen.dart
lib/main.dart
nginx.conf
plans/akilli-merkezi-beyin-detayli-plan.md
plans/sourcebase-design-system-implementation.md
plans/sourcebase-design-system-plan.md
plans/sourcebase-production-plan.md
pubspec.lock
pubspec.yaml
supabase/config.toml
supabase/deno.json
supabase/functions/_shared/cors.ts
supabase/functions/_shared/supabase-client.ts
supabase/functions/ai-services/deno.json
supabase/functions/ai-services/index.ts
supabase/functions/sourcebase/AI_GENERATION_API.md
supabase/functions/sourcebase/AI_IMPLEMENTATION_SUMMARY.md
supabase/functions/sourcebase/README.md
supabase/functions/sourcebase/actions/ai-generation.ts
supabase/functions/sourcebase/index.ts
supabase/functions/sourcebase/services/extraction.ts
supabase/functions/sourcebase/services/job-processor.ts
supabase/functions/sourcebase/services/vertex-ai.ts
supabase/functions/sourcebase/types.ts
supabase/functions/sourcebase/validators/content.ts
supabase/import_map.json
supabase/migrations/20260515_create_sourcebase_drive_schema.sql
supabase/migrations/20260516120012_vector_support.sql
supabase/migrations/20260516120100_create_find_similar_rpc.sql
supabase/migrations/20260516120448_automate_embedding_triggers.sql
supabase/migrations/20260516120617_knowledge_graph_schema.sql
supabase/migrations/20260516_complete_sourcebase_schema.sql
supabase/migrations/20260516_fix_generated_jobs_ai_schema.sql
supabase/migrations/MIGRATION_SUMMARY.md
supabase/migrations/QUICK_REFERENCE_SCHEMA.md
supabase/migrations/README_20260516_SCHEMA.md
supabase/migrations/test_20260516_migration.sql
test/widget_test.dart
test_build.sh
web/flutter_bootstrap.js
web/index.html
web/manifest.json
```

Binary/resource assetleri de var:

```text
assets/brand/sourcebase_mark.png
assets/brand/sourcebase_wordmark.png
android/app/src/main/res/mipmap-*/ic_launcher.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png
web/favicon.png
web/icons/*.png
```

## Ajan Prompt'una Eklenebilecek Kisa Not

Bu repo Flutter + Supabase SourceBase uygulamasidir. Once `SourceBase-Repo-Haritasi-2026-05-16.md` dosyasini oku. Kod ararken ana girisler: `lib/main.dart`, `lib/app/sourcebase_app.dart`, `lib/features/drive/data/sourcebase_drive_api.dart`, `lib/features/drive/data/drive_repository.dart`, `supabase/functions/sourcebase/index.ts`. Degisiklik yaparken mevcut dirty worktree'yi koru, unrelated dosyalari revert etme, service role key'i Flutter/browser tarafina tasima.
