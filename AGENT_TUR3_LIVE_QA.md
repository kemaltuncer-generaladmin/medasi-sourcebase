# TUR 3 CANLI UX RAPORU - BACKEND + AI + SECURITY

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: Desktop 1440x900, Tablet 1024x1366, iPhone 14 390x844; API testleri canlı HTTP/curl ile
- Tarayıcı: Google Chrome headless/Playwright ile login ekranına kadar; canlı API için curl
- Tarih/saat: 2026-05-18 05:07 +03

## 2. Gerçekten denenen akışlar
- Canlı app shell açıldı: `https://sourcebase.medasi.com.tr` HTTP 200.
- Desktop/tablet/iPhone 14 viewportlarında login ekranı açıldı.
- Console/pageerror/network gözlemi login ekranına kadar alındı.
- Gerçek test hesabıyla Supabase Auth endpointine canlı login denendi: HTTP 200, access token üretildi.
- Auth olmadan `drive_bootstrap` canlı Edge Function çağrısı denendi.
- Auth ile `drive_bootstrap` canlı Edge Function çağrısı denendi.
- Auth ile `create_course`, `create_section`, `create_upload_session` denendi.
- Signed URL ile gerçek dosya PUT yapılmadan `complete_upload` denendi.
- Auth ile `create_generation_job` denendi.
- Auth ile `central_ai_chat` denendi.
- QA sırasında açılan test course temizlenmeye çalışıldı.

## 3. Çalışanlar
- Login ekranı web/tablet/iPhone 14 viewportlarında açılıyor.
- Login ekranında kırmızı runtime `pageerror` gözlenmedi.
- Auth endpoint gerçek test hesabıyla HTTP 200 döndü.
- Auth olmadan `drive_bootstrap` doğru şekilde HTTP 401 ve sade JSON hata döndü: `UNAUTHORIZED / Oturum gerekli.`
- Auth ile `drive_bootstrap` HTTP 200 döndü; response anahtarları: `storage`, `ai`, `courses`, `sections`, `files`, `generatedOutputs`.
- `create_course` HTTP 200 döndü ve test course kaydı oluşturdu.
- `create_section` HTTP 200 döndü ve course altında section oluşturdu.
- `create_upload_session` HTTP 200 döndü; `uploadUrl`, `objectName`, `bucket`, `expiresAt`, `headers`, `metadata` mevcut.
- Response içinde service role, private key, access token, refresh token veya stack trace kelimeleri görülmedi.

## 4. Kırılanlar
- Release blocker: `complete_upload`, signed URL ile gerçek upload yapılmadan HTTP 200 döndü ve `drive_files` kaydı oluşturdu. Response `status: processing_failed`, `ai_status: failed`, `metadata.extractionError: Dosya indirilemedi.` içeriyor. Bu, sahte/bozuk upload'ın tamamlanmış dosya gibi DB'ye yazılabildiğini gösteriyor.
- Release blocker: `create_generation_job` canlı ortamda HTTP 500 döndü: `VERTEX_AUTH_FAILED / Vertex AI kimlik doğrulama başarısız.`
- Release blocker: `central_ai_chat` canlı ortamda HTTP 500 döndü: `VERTEX_AUTH_FAILED / Vertex AI kimlik doğrulama başarısız.`
- Major issue: Canlı app shell domaininde `https://sourcebase.medasi.com.tr/functions/v1/sourcebase` HTTP 405 döndü; gerçek fonksiyon endpointi canlı bundle configinden `https://medasi.com.tr/functions/v1/sourcebase` olarak çalıştı. Bu routing/konfigürasyon ayrımı frontend/network debug için riskli.
- Major issue: `OPTIONS https://sourcebase.medasi.com.tr/functions/v1/sourcebase` HTTP 405 döndü; `https://medasi.com.tr/functions/v1/sourcebase` response headerında `access-control-allow-origin: *` görüldü. Production CORS beklenen sıkılıkta değil.
- Major issue: QA cleanup için `delete_course` çağrısı HTTP 500 döndü: `GCS_DELETE_FAILED / Dosya depolama alanından silinemedi.` Test course/file canlı test hesabında kalmış olabilir.

## 5. Release blocker
- Var
- Detay: Upload tamamlanmadan `complete_upload` dosya kaydı açabiliyor. AI üretim ve Central AI canlı Vertex auth hatasıyla 500 dönüyor. Bu iki alan SourceBase'in ana ürün vaadi olan kaynak yükleme ve kaynaklardan AI çıktı üretme akışını canlıda bloke ediyor.

## 6. Major issue
- CORS canlı fonksiyon endpointinde `*` dönüyor; production security hedefiyle uyumsuz.
- App domainindeki `/functions/v1/sourcebase` 405 döndüğü için canlı URL altında beklenen proxy/routing net değil.
- `delete_course` GCS delete hatası nedeniyle QA datası temizlenemedi; kullanıcı açısından dosya/course silme akışı da riskli.

## 7. Polish issue
- Login ekranındaki erişilebilirlik/DOM uyarısı: `Password field is not contained in a form`. Kritik runtime hata değil.
- Login ekranında bazı button metinleri erişilebilir isimde iki kez görünüyor: `Giriş Yap Giriş Yap`, `Hesap Oluştur Hesap Oluştur`.

## 8. Kullanıcı deneyimi kararı
- Evet/Hayır/Kısmen: Hayır. Kullanıcı canlıda login ekranına ulaşabiliyor ve Drive bootstrap/course/section/upload session API'leri cevap veriyor; ancak dosya upload tamamlanma güvenliği ve AI üretim/Central AI canlıda release blocker seviyesinde kırık.

## 9. Patch gerekiyor mu?
- Evet
- Gereken dosyalar: Backend/Edge Function canlı deploy içeriği ve ortam değişkenleri. Özellikle `complete_upload` canlı doğrulaması, Vertex AI credential/env, CORS/origin config ve GCS delete davranışı düzeltilmeli. Kod dosyası olarak mevcut branch'teki `supabase/functions/sourcebase/index.ts`, `supabase/functions/sourcebase/actions/ai-generation.ts`, `supabase/functions/sourcebase/services/vertex-ai.ts` ve deploy/Coolify env incelenmeli.

## 10. Kanıt / not
- Console hatası: Login ekranına kadar kırmızı `pageerror` yok. Console sadece Flutter boot debug ve Chrome DOM uyarısı verdi.
- Network hatası: Login ekranına kadar failed request yok. API testlerinde `sourcebase.medasi.com.tr/functions/v1/sourcebase` 405; `create_generation_job` ve `central_ai_chat` 500; `delete_course` 500.
- Ekran gözlemi: Desktop/tablet/iPhone 14 login ekranı açıldı; metinler ve inputlar görünür. Gerçek hesapla post-login browser UX bu makinede tamamlanamadı.
- Manuel test yapılamadıysa nedeni: Makinede `/System/Volumes/Data` tamamen dolu, Playwright Chromium kurulumu `ENOSPC` ile başarısız oldu. Kurulu Chrome ile login sonrası otomasyon da Crashpad/ProcessSingleton yazımı sırasında `ENOSPC` nedeniyle durdu. Bu nedenle post-login browser Network testi yerine canlı Auth ve Edge Function API testleri curl ile yapıldı.
