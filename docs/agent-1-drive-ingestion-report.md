# Agent 1 Drive Ingestion Report

## Kok Neden

- PDF extractor yalnizca basit `Tj`/`TJ` text operatorlarini ve sinirli Flate stream cozumlemeyi okuyordu. Gercek text tabanli PDF'lerde ToUnicode CMap kullanan font encoding'leri metin oldugu halde bos sonuc uretebiliyor ve taranmis PDF mesaji false negative gibi gorunebiliyordu.
- `extractTextFromDriveFile` route karari once DB'deki `file_type` alanina guveniyordu. Rsync veya eski kayitlardan kalan stale `file_type` degerleri gercek `.pptx`/`.docx` dosyalarini unsupported ya da legacy limited-support yoluna dusurebiliyordu.
- `complete_upload` fake-upload korumasi duruyordu, ancak client tarafinda `ai_status` bos ve `status=uploaded` eski kayitlar tamamlanmis gibi yorumlanabiliyordu.
- Klasor icinden uretim adayi secimi, hazir olmayan dosyalari aday listeden ayirmiyordu; ana generation entrypoint reddediyordu ama secim ergonomisi net degildi.

## Degisen Dosyalar

- `supabase/functions/sourcebase/services/extraction.ts`
- `supabase/functions/sourcebase/services/extraction.test.ts`
- `supabase/functions/sourcebase/actions/ai-generation.ts`
- `lib/features/drive/data/drive_repository.dart`
- `lib/features/drive/presentation/screens/folder_screen.dart`
- `maestro/flows/drive_ingestion_agent1.yaml`
- `docs/agent-1-drive-ingestion-report.md`

## Format Destek Matrisi

| Format | Durum | Davranis |
| --- | --- | --- |
| PDF text-based | Destekleniyor | Literal/hex text operatorlari, Flate stream'ler ve ToUnicode CMap ile metin cikarilir. |
| PDF scanned/image | Sinirli destek | Net OCR mesaji: taranmis/gorsel tabanli PDF icin OCR gerekir. |
| PPTX | Destekleniyor | Slide, notes ve slide master XML metinleri cikarilir. |
| PPT | Sinirli destek | Legacy binary parser yok; kullaniciya `.pptx` olarak kaydedip tekrar yukleme mesaji doner. |
| DOCX | Destekleniyor | Body, header ve footer XML metinleri cikarilir. |
| DOC | Sinirli destek | Legacy binary parser yok; kullaniciya `.docx` olarak kaydedip tekrar yukleme mesaji doner. |

## Korunan Patch'ler

- `complete_upload` fake-upload korumasi korunuyor: object path, GCS metadata, object name, size ve MIME dogrulamasi devam ediyor.
- `process_generation_job` ayrik action olarak korunuyor; queued job olusturma ve sonradan isleme akisi bozulmadi.
- 0 KB dosyalar backend ve client tarafinda hazir kaynak gibi kullanilamaz.
- Missing object ve unsupported/limited-support dosyalar extraction fail ile `ai_status=failed` durumuna duser.
- Failed/processing/draft kaynaklar Drive generation aday seciminde ve SourceLab secimlerinde kullanilamaz.

## Test Sonuclari

- `deno test --no-check --allow-all supabase/functions/sourcebase/services/file-types.test.ts supabase/functions/sourcebase/services/extraction.test.ts`: gecti, 10/10.
- `deno check supabase/functions/sourcebase`: gecti.
- `deno check supabase/functions/ai-services`: gecti.
- `flutter analyze`: gecti, no issues found.
- `flutter test`: gecti, 5/5.
- `git diff --check`: gecti.

## Maestro Mini Flow

- Flow dosyasi: `maestro/flows/drive_ingestion_agent1.yaml`
- Sonuc: calistirilamadi. `maestro --version` Java Runtime bulunamadigi icin basarisiz oldu; cihaz/simulator testi icin yerel Java Runtime kurulumu gerekiyor.

## Kalan Riskler

- PDF parser halen pure TypeScript ve hafif agirlikli. Cok karmasik object stream, sifreli PDF, coklu filter zinciri veya ozel font encoding'lerinde profesyonel PDF/OCR servisi gerekebilir.
- Legacy `.ppt` ve `.doc` binary formatlari parse edilmiyor; kullaniciya donusum onerisi veriliyor.
- Canli GCS upload ve Edge Function entegrasyonu local unit/check ile sinirli dogrulandi; deploy sonrasi canli bucket uzerinde smoke test gerekir.

## Canli Edge Deploy Komutlari

```bash
supabase functions deploy sourcebase
supabase functions deploy ai-services
```
