# Agent 3 SourceLab ve Merkezi AI Raporu

## Teşhis Özeti

- SourceLab ekranı: `lib/features/sourcelab/presentation/screens/source_lab_screen.dart`
- Merkezi AI ekranı: `lib/features/central_ai/presentation/screens/central_ai_screen.dart`
- Flutter API client: `lib/features/drive/data/sourcebase_drive_api.dart`
- AI action router: `supabase/functions/sourcebase/index.ts`
- Job actionları: `supabase/functions/sourcebase/actions/ai-generation.ts`
- Job işleme ve `generated_outputs` persist: `supabase/functions/sourcebase/services/job-processor.ts`
- Provider çağrıları: `supabase/functions/sourcebase/services/vertex-ai.ts`, OpenAI/Anthropic route fallback servisleri ve infografik image provider.

`create_generation_job -> process_generation_job -> get_job_status polling -> get_generated_content` sırası korunmuştur. Fire-and-forget background processing eklenmedi.

## Mod Bazlı Durum Matrisi

| Mod | Kaynak seçimi | Provider çağrısı | Polling/result | generated_outputs | Mock/fake durumu | Queued riski |
| --- | --- | --- | --- | --- | --- | --- |
| Klinik Senaryo | Tüm workspace Drive dosyaları, sadece hazır kaynak seçilebilir | `generateClinicalScenario` gerçek text provider | Var | `clinical_scenario` olarak kaydedilir | Mock yok | Kaynak okuma hatasında failed status'a çekildi |
| Öğrenme Planı | Tüm workspace Drive dosyaları, sadece hazır kaynak seçilebilir | `generateLearningPlan` gerçek text provider | Var | `learning_plan` olarak kaydedilir | Mock yok | Kaynak okuma hatasında failed status'a çekildi |
| Podcast Özeti | Tüm workspace Drive dosyaları, sadece hazır kaynak seçilebilir | `generatePodcast` gerçek text provider | Var | `podcast_summary` olarak kaydedilir | Ses üretimi yok; metinsel script gerçek AI çıktısı | Kaynak okuma hatasında failed status'a çekildi |
| İnfografik | Tüm workspace Drive dosyaları, sadece hazır kaynak seçilebilir | Text spec + image provider | Var | `infographic` olarak kaydedilir | Mock yok | Provider/image hatası failed status + refund |
| Zihin Haritası | Tüm workspace Drive dosyaları, sadece hazır kaynak seçilebilir | `generateMindMap` gerçek text provider | Var | `mind_map` olarak kaydedilir | Mock yok | map seçenekleri metadata'ya yazılıyor; kaynak okuma hatası failed |

## Merkezi AI Durum Analizi

- Flutter ekranı `central_ai_chat` action'ını çağırıyor.
- Önceden sadece metinsel dosya özeti gönderiliyordu; artık seçili hazır Drive dosya id'leri `fileIds` olarak backend'e taşınıyor.
- Backend `buildOwnedFileContext` ile bu dosyaları owner kontrolünden geçirip extraction sonucunu gerçek context olarak modele veriyor.
- Merkezi AI kaynak listesi artık sadece `recentFiles` değil, workspace içindeki tüm course/section dosyaları üzerinden oluşuyor.
- Provider/raw hata kodları kullanıcıya `VERTEX_AUTH_FAILED`, stack, raw JSON, `undefined`, `null` şeklinde gösterilmeyecek şekilde filtrelendi.

## Provider Call Doğrulama Yöntemi

- SourceLab modlarının job type eşleşmesi `_sourceLabJobType` üzerinden doğrulandı.
- `process_generation_job` action'ının `JobProcessor.processJob` çağırdığı ve provider loglarında `provider_start`, `provider_done`, `output_saved`, `completed/failed` statülerini kullandığı doğrulandı.
- `JobProcessor.generate` içinde klinik senaryo, öğrenme planı, podcast, infografik ve zihin haritası gerçek Vertex/Text route metodlarına gidiyor.
- Canlı provider smoke testi yapılmadı; secret yazdırmadan statik akış, Deno type-check, Flutter analyze/test/build ile doğrulandı.

## Değişen Dosyalar

- `lib/features/central_ai/presentation/screens/central_ai_screen.dart`
- `lib/features/drive/data/sourcebase_drive_api.dart`
- `lib/features/sourcelab/presentation/screens/source_lab_screen.dart`
- `supabase/functions/sourcebase/actions/ai-generation.ts`
- `supabase/functions/sourcebase/services/job-processor.ts`
- `maestro/flows/sourcelab_ai_agent3.yaml`
- `docs/agent-3-sourcelab-ai-report.md`

## Test Sonuçları

- `flutter analyze`: geçti, no issues found.
- `flutter test`: geçti, 5/5.
- `flutter build web`: geçti, web build üretildi.
- `deno check supabase/functions/sourcebase`: geçti.
- `deno check supabase/functions/ai-services`: geçti.
- `git diff --check`: geçti.

Not: `deno check sourcebase` ilk denemede macOS AppleDouble `._*.ts` metadata dosyaları nedeniyle parse hatası verdi. Kod dosyası olmayan bu local metadata dosyaları kaldırıldı ve check geçti.

## Maestro Mini Flow

- Flow dosyası: `maestro/flows/sourcelab_ai_agent3.yaml`
- Çalıştırma sonucu: çalıştırılamadı.
- Neden: Lokal ortamda Maestro Java runtime bulamadı: `Unable to locate a Java Runtime`.

## Kalan P0/P1 Riskler

- P0: Yok.
- P1: Canlı provider smoke testi secret kullanmadan yapılmadı; provider credential/runtime hataları staging ortamında ayrıca izlenmeli.
- P1: Maestro flow Java runtime ve aktif simulator/device olmadan lokal doğrulanamadı.

## Agent 1 Drive'a Bağımlı Noktalar

- SourceLab ve Merkezi AI, Drive workspace'in `courses -> sections -> files` yapısının doğru ve eksiksiz dönmesine bağlı.
- Backend context extraction hâlâ Agent 1'in Drive ingestion/extraction pipeline çıktısına bağlı.
- Dosya `status`, `gcs_bucket`, `gcs_object_name`, `file_type`, `mime_type` alanları hatalıysa AI context ve SourceLab üretimi failed status'a düşer; bu alanların doğruluğu Drive tarafının sorumluluğunda kalır.
