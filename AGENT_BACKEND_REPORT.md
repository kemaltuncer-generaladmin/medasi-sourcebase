# AJAN 1 — BACKEND / SECURITY / MC / EDGE RAPORU

## 1. Branch ve Repo Doğrulaması

- Repo kökü: `/Volumes/driveand/sourcebase-agents/sb-backend`
- Branch: `agent/backend-security-mc`
- Status:
  - `M supabase/functions/sourcebase/actions/ai-generation.ts`
  - `M supabase/functions/sourcebase/index.ts`
  - `M supabase/functions/sourcebase/services/job-processor.ts`
  - `AGENT_BACKEND_REPORT.md` bu rapor için oluşturuldu.

## 2. İncelediğim Alanlar

- Edge Function routing: `supabase/functions/sourcebase/index.ts`
- `purchase_medasicoin` action durumu ve Store çağrısına backend cevabı
- `complete_upload` güvenliği, upload validation, GCS metadata doğrulaması
- `create_generation_job` job oluşturma ve MC rezervasyon sırası
- `process_generation_job` senkron job işleme akışı
- MC `reserve` / `capture` / `refund` muhasebe akışı
- `generated_outputs` persist ve idempotency kontrolü
- CSP, RLS, grant ve release güvenlik riskleri

## 3. Yaptığım Değişiklikler

### `supabase/functions/sourcebase/index.ts`

- Ne değişti:
  - Edge Function router'a `purchase_medasicoin` action eklendi.
  - `purchaseMedasiCoin` minimum güvenli backend handler'ı eklendi.
  - Handler `product_code` alanını doğruluyor ve gerçek ödeme sağlayıcı entegrasyonu olmadığı için `PAYMENT_UNAVAILABLE` / 503 dönüyor.
- Neden değişti:
  - Store akışı backend'de eksik action nedeniyle `UNKNOWN_ACTION` alıyordu.
  - Gerçek ödeme sağlayıcı olmadan sahte başarı veya sahte MC yükleme yapılmaması gerekiyordu.
- Risk seviyesi:
  - Düşük. MC bakiyesi yazmıyor, ödeme alınmış gibi davranmıyor, sadece güvenli unavailable cevabı veriyor.

### `supabase/functions/sourcebase/actions/ai-generation.ts`

- Ne değişti:
  - `create_generation_job` içinde job oluşturulduktan sonra MC rezervasyonu başarısız olursa job `failed` durumuna çekiliyor.
  - Rezervasyon hatası `errorCode` ve `failedAt` metadata alanlarına yazılıyor.
  - `process_generation_job`, status `processing` olan job'ı tekrar provider'a göndermiyor; mevcut processing durumunu döndürüyor.
- Neden değişti:
  - Rezervasyon başarısızlığında aktif kuyrukta rezervasyonsuz job kalmasını önlemek için.
  - Aynı job'ın tekrar işlenmesiyle duplicate provider çağrısı ve duplicate refund riskini azaltmak için.
- Risk seviyesi:
  - Orta-düşük. Mevcut generation pipeline korunuyor; sadece hata ve tekrar çağrı guard'ları eklendi.

### `supabase/functions/sourcebase/services/job-processor.ts`

- Ne değişti:
  - Başarılı generation sonrası MC `capture` muhasebe kaydı `try/catch` içine alındı.
  - Capture bookkeeping hatası artık tamamlanmış job'ı catch/refund/failed yoluna düşürmüyor; güvenli hata kodu loglanıyor.
- Neden değişti:
  - Output kaydedildikten ve job completed olduktan sonra sıfır tutarlı capture kaydı başarısız olursa “çıktı üretildi ama refund/failed oldu” tutarsızlığını önlemek için.
- Risk seviyesi:
  - Orta. Capture kaydı muhasebe/audit görünürlüğü için önemli; fakat amount `0` olduğu için kullanıcı bakiyesini değiştirmiyor. Release QA bu logları izlemeli.

## 4. Değişen Dosyalar

- `supabase/functions/sourcebase/index.ts`
- `supabase/functions/sourcebase/actions/ai-generation.ts`
- `supabase/functions/sourcebase/services/job-processor.ts`
- `AGENT_BACKEND_REPORT.md`

## 5. Test ve Kontrol Komutları

- `pwd`
  - Sonuç: `/Volumes/driveand/sourcebase-agents/sb-backend`
- `git rev-parse --show-toplevel`
  - Sonuç: `/Volumes/driveand/sourcebase-agents/sb-backend`
- `git branch --show-current`
  - Sonuç: `agent/backend-security-mc`
- `git status --short`
  - Başlangıçta yalnızca daha önceki backend patch dosyaları modified görünüyordu.
  - Finalde backend patch dosyaları ve bu rapor dosyası değişmiş durumdadır.
- `deno fmt --check supabase/functions/sourcebase/index.ts supabase/functions/sourcebase/actions/ai-generation.ts supabase/functions/sourcebase/services/job-processor.ts`
  - Sonuç: geçti.
- `deno check supabase/functions/sourcebase/index.ts`
  - Sonuç: geçti.
- `deno test --allow-read --allow-write=test/fixtures/sourcebase supabase/functions/sourcebase/services/file-types.test.ts supabase/functions/sourcebase/services/extraction.test.ts`
  - Sonuç: geçti, 10 test başarılı, 0 başarısız.
  - Not: Test komutu `test/fixtures/sourcebase/valid_cmap_pdf.pdf` fixture artefaktını üretti; gerçek patch parçası olmadığı için kaldırıldı.
- `git diff --check`
  - Sonuç: geçti.
- `git diff --stat`
  - Sonuç: backend patch 3 dosyada, bu rapor ayrı dosyada.

## 6. Release Blocker'lar

- `purchase_medasicoin` gerçek ödeme sağlayıcı olmadan ne durumda?
  - Backend artık `UNKNOWN_ACTION` dönmüyor.
  - Gerçek ödeme sağlayıcı entegrasyonu olmadığı için güvenli şekilde `PAYMENT_UNAVAILABLE` / 503 dönüyor.
  - MC bakiyesi eklemiyor, ödeme alınmış gibi davranmıyor, checkout URL üretmiyor.
  - Release için karar gerekli: Store satın alma UI production'da kapalı mı kalacak, yoksa gerçek ödeme provider entegrasyonu mu eklenecek?

- CSP durumu:
  - `nginx.conf` içinde `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`, `Permissions-Policy` mevcut.
  - `Content-Security-Policy` header'ı yok.
  - Release/QA ajanı CSP'yi web build, Supabase endpointleri, GCS signed URL akışı ve Flutter web asset ihtiyaçlarıyla birlikte test ederek eklemeli.

- RLS/grant riski:
  - `supabase/migrations/20260517201000_grant_sourcebase_rest_access.sql` anon/authenticated için geniş table grant içeriyor.
  - RLS policy'leri bu erişimi sınırlamalı; fakat release öncesi gerçek DB üzerinde anon/authenticated/service_role smoke testi yapılmalı.
  - Migration değiştirilmedi; bu risk sadece raporlandı.

- Atomic job claim riski:
  - `process_generation_job` için `processing` guard eklendi.
  - Bu guard tekrar çağrıları azaltır; ancak tam atomik claim için DB seviyesinde conditional update/RPC veya lock gerekir.
  - Migration/RPC değiştirilmediği için milisaniye seviyesinde eşzamanlı iki isteğin yarış riski tamamen kapanmış sayılmaz.

- Payment sahte başarı riski var mı?
  - Bu patch sonrası backend tarafında `purchase_medasicoin` sahte başarı üretmiyor.
  - MC bakiyesi kullanıcıdan para alınmış gibi artırılmıyor.
  - Store UI, backend unavailable cevabını hata olarak göstermeli; UI dosyalarına dokunulmadı.

## 7. Diğer Ajanlara Handoff

- Drive ajanı:
  - `complete_upload` güvenlik zinciri korunuyor: user prefix, sanitized filename, GCS object metadata, size ve MIME doğrulaması devam ediyor.
  - Upload akışında fake upload korumasını zayıflatacak değişiklik yapılmadı.

- BaseForce ajanı:
  - `create_generation_job -> process_generation_job -> poll/read generated output` akışı korunuyor.
  - `processing` durumunda tekrar provider çağrısı yapılmaması BaseForce polling davranışıyla uyumlu olmalı; UI `alreadyProcessing` dönen cevabı hata gibi ele almamalı.

- SourceLab ajanı:
  - SourceLab generation türleri ve `generated_outputs` persist akışı korunuyor.
  - Provider hatalarında refund akışı devam ediyor; tamamlanmış output sonrası capture bookkeeping hatası artık output'u failed/refund yapmıyor.

- QA ajanı:
  - Store purchase smoke testinde beklenen backend cevabı: `PAYMENT_UNAVAILABLE`, ödeme alınmadı mesajı.
  - Generation smoke testleri şunları kapsamalı: queued job oluşturma, MC reserve, `process_generation_job`, status polling, generated output read, provider failure refund, aynı job'a tekrar `process_generation_job` çağrısı.
  - Upload smoke testleri şunları kapsamalı: gerçek GCS PUT sonrası complete, 0 byte reject, size mismatch reject, MIME mismatch reject, foreign object path reject.
  - CSP ve RLS/grant kontrolleri release öncesi ayrıca yapılmalı.

## 8. Merge Kararı

- Merge için güvenli mi?
  - Evet, backend patch olarak güvenli görünüyor.

- Hangi şartlarla güvenli?
  - Store satın alma akışı gerçek ödeme sağlayıcı olmadan production'da sahte başarı beklememeli.
  - `PAYMENT_UNAVAILABLE` cevabı ürün/QA tarafından kabul edilmeli veya Store satın alma UI production'da kapatılmalı.
  - RLS/grant ve CSP maddeleri release öncesi açık takip maddesi olarak kalmalı.

- Hangi testler geçmeli?
  - `deno fmt --check supabase/functions/sourcebase/index.ts supabase/functions/sourcebase/actions/ai-generation.ts supabase/functions/sourcebase/services/job-processor.ts`
  - `deno check supabase/functions/sourcebase/index.ts`
  - `deno test --allow-read --allow-write=test/fixtures/sourcebase supabase/functions/sourcebase/services/file-types.test.ts supabase/functions/sourcebase/services/extraction.test.ts`
  - `git diff --check`
  - Staging smoke: upload complete, generation reserve/process/poll/read, provider failure refund, purchase unavailable, RLS anon/authenticated negative tests.
