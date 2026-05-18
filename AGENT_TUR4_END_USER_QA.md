# TUR 4 SON KULLANICI QA RAPORU - BACKEND + AI + SECURITY

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: Desktop 1440x900, Tablet 1024x1366, iPhone 14 390x844; ek canlı API testleri HTTP/curl ile
- Tarayıcı: Google Chrome headless + Playwright persistent context
- Tarih/saat: 2026-05-18 05:55 +03

## 2. Son kullanıcı senaryosu
Kullanıcı SourceBase'e giriş yapıp Drive ana ekranına ulaşmak, ders/bölüm altında kaynak yüklemek, yüklenen kaynaktan AI öğrenme çıktısı üretmek ve Central AI'dan kaynak bağlamıyla yanıt almak istiyor. Backend açısından kritik beklenti: kullanıcı sadece kendi verisini görmeli, upload gerçekten tamamlanmadan dosya başarılı sayılmamalı, AI job ve Central AI canlıda çalışmalı, hata response'u sade kalmalı ve secret/stack trace dönmemeli.

## 3. Gerçekten denenen akışlar
- Canlı URL desktop/tablet/iPhone 14 viewportlarında açıldı.
- Gerçek test hesabıyla canlı login formu dolduruldu ve `Giriş Yap` butonuna basıldı.
- Login sonrası Drive home ekranı açıldı.
- Browser Network gözleminde `drive_bootstrap` çağrısı görüldü.
- Canlı API'de auth olmadan `drive_bootstrap` çağrıldı.
- Canlı API'de auth ile `create_course`, `create_section`, `create_upload_session`, `complete_upload`, `create_generation_job`, `central_ai_chat`, `delete_course` çağrıldı.
- Sahte upload senaryosu denendi: `create_upload_session` sonrası GCS PUT yapılmadan `complete_upload` çağrıldı.
- Gerçek upload senaryosu denendi: `create_upload_session` sonrası signed URL'ye PDF `PUT` denendi, ardından `complete_upload` çağrıldı.
- CORS preflight canlı API domaininde denendi.
- Response gövdelerinde stack trace, service role, private key, access/refresh token marker'ları arandı.

## 4. Çalışanlar
- Login canlıda başarılı: Auth token endpoint browser ve API testinde HTTP 200 döndü.
- Desktop/tablet/iPhone 14 viewportlarında kullanıcı login sonrası `#/home` rotasına geçti.
- Drive home açılıyor; `drive_bootstrap` browser Network'te HTTP 200 döndü.
- Auth olmadan `drive_bootstrap` doğru şekilde HTTP 401 ve sade JSON hata döndürdü: `UNAUTHORIZED / Oturum gerekli.`
- Auth ile `create_course` HTTP 200 döndü.
- Auth ile `create_section` HTTP 200 döndü.
- Auth ile `create_upload_session` HTTP 200 döndü ve `uploadUrl`, `objectName`, `bucket`, `expiresAt`, `headers`, `metadata` alanlarını verdi.
- Hata response'larında stack trace, service role, private key, access token veya refresh token marker'ı görülmedi.
- Login sonrası desktop/tablet/iPhone 14 görünümünde kritik runtime `pageerror` veya failed browser request gözlenmedi.

## 5. Kırılanlar
- Sahte `complete_upload` hâlâ başarısız değil: GCS PUT yapılmadan çağrılan `complete_upload` HTTP 200, `ok: true`, `status: processing_failed` döndü ve `drive_files` kaydı açtı. Bu canlı deploy'da upload doğrulamasının release blocker olarak kırık olduğunu kanıtlıyor.
- Gerçek upload denemesinde signed URL `PUT` HTTP 403 döndü. Buna rağmen ardından çağrılan `complete_upload` yine HTTP 200, `ok: true`, `status: processing_failed`, `ai_status: failed`, `file_id_present: true` döndü.
- `create_generation_job` HTTP 500 döndü: `VERTEX_AUTH_FAILED / Vertex AI kimlik doğrulama başarısız.`
- `central_ai_chat` HTTP 500 döndü: `VERTEX_AUTH_FAILED / Vertex AI kimlik doğrulama başarısız.`
- `delete_course` cleanup HTTP 500 döndü: `GCS_DELETE_FAILED / Dosya depolama alanından silinemedi.`
- CORS preflight canlı API domaininde HTTP 200 döndü ama `access-control-allow-origin: *` ve çok geniş method listesi var: `GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS,TRACE,CONNECT`.

## 6. Release blocker
- Var/Yok: Var
- Detay: Kullanıcı SourceBase'in ana amacına ulaşamıyor. Drive açılıyor ama upload güvenliği canlıda kırık: upload yapılmadan dosya kaydı oluşturulabiliyor. Signed upload gerçek PUT 403 verdiği için gerçek dosya yükleme de kullanılamıyor. AI üretim ve Central AI canlıda `VERTEX_AUTH_FAILED` ile 500 dönüyor. Bu, kaynak yükleme ve kaynaktan öğrenme çıktısı üretme vaadini bloke ediyor.

## 7. Major issue
- CORS production için makul değil: canlı API `*` origin ve gereksiz geniş method listesi dönüyor.
- App shell domaini `sourcebase.medasi.com.tr`, canlı API hostu bundle configte `medasi.com.tr`; kullanıcı açısından çalışıyor ama operational/debug açısından tutarsız.
- `delete_course` GCS silme hatasına takılıp 500 dönüyor; QA verisi ve kullanıcı verisi temizlenemeyebilir.
- Test hesabında önceki canlı QA'dan kalan hatalı dosya ekranda görünüyor: `tur3_live_qa.pdf. 0 KB. ... Hata.`

## 8. Polish issue
- Login ekranında ve Drive CTA'da bazı erişilebilir buton metinleri tekrar ediyor: `Giriş Yap Giriş Yap`, `Kaynak Oluştur Kaynak Oluştur`.
- Chrome console'da login ekranı için DOM uyarısı görüldü; kırmızı runtime hata değil.
- iPhone 14 görünümünde Drive ilk ekran kullanılabilir, ancak sadece ilk birkaç ders görünüyor; uzun liste ve QA kalıntıları kullanıcı algısını zayıflatıyor.

## 9. Kullanıcı deneyimi kararı
- Kullanıcı bu alanda amacına ulaşabiliyor mu?
- Hayır
- Neden? Kullanıcı giriş yapıp Drive ana ekranını görebiliyor, ancak SourceBase'in asıl değeri olan güvenli dosya yükleme ve AI çıktı üretme canlıda çalışmıyor. Sahte upload başarıya yakın bir state yaratıyor, gerçek PUT 403 veriyor, generation job ve Central AI 500 ile duruyor.

## 10. Patch gerekiyor mu?
- Evet/Hayır: Evet
- Gerekirse hangi dosyalar: Canlı deploy'a alınması gereken backend patch alanları `supabase/functions/sourcebase/index.ts`, `supabase/functions/sourcebase/actions/ai-generation.ts`, `supabase/functions/sourcebase/services/vertex-ai.ts`, `supabase/functions/_shared/cors.ts`; ayrıca Coolify/Supabase env ve routing ayarları.
- Patch önceliği: blocker

## 11. Kanıt / not
- Console hatası: Login sonrası kritik `pageerror` yok. Console'da Flutter boot debug ve redakte edilen hassas olabilecek verbose DOM satırı dışında kritik hata gözlenmedi.
- Network hatası: Browser login sonrası `drive_bootstrap` HTTP 200. API kanıtları: sahte `complete_upload` HTTP 200/`ok:true`; real signed `PUT` HTTP 403; real `complete_upload` HTTP 200/`ok:true`; `create_generation_job` HTTP 500 `VERTEX_AUTH_FAILED`; `central_ai_chat` HTTP 500 `VERTEX_AUTH_FAILED`; `delete_course` HTTP 500 `GCS_DELETE_FAILED`; CORS `allow-origin: *`.
- Ekran gözlemi: Desktop/tablet/iPhone 14 login sonrası Drive home açıldı. Ekranda ders listeleri, `Kaynak Oluştur`, `Ders Oluştur`, `Bölüm Ekle`, `Koleksiyonlar` CTA'ları görünüyor. Tablet görünümünde önceki hatalı upload dosyası `0 KB / Hata` olarak listeleniyor.
- Manuel test yapılamadıysa nedeni: GUI manuel olarak kullanılmadı; gerçek Chrome headless ile son kullanıcı login/viewport/network testi yapıldı. Dosya seçici üzerinden manuel upload yerine canlı API ile signed upload akışı test edildi. Test sonrası token/session içerebilecek geçici Chrome profilleri ve QA dosyaları silindi.
