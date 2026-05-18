# TUR 4 SON KULLANICI QA RAPORU - DRIVE + UPLOAD

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: Desktop 1440x900, iPhone 14 390x844, tablet 820x1180 temel giriş denemesi
- Tarayıcı: Google Chrome, Playwright headless
- Tarih/saat: 2026-05-18 05:51-05:54 +03

## 2. Son kullanıcı senaryosu
Kullanıcı Drive'a girip kendi PDF kaynağını yüklemek, bunu ders ve bölüm altında düzenlemek, yüklenen dosyayı listede görmek, dosya detayına girip durumunu anlamak ve hazırsa öğrenme çıktısı üretmek istiyor.

## 3. Gerçekten denenen akışlar
- Canlı login ekranı açıldı, e-posta/şifre ile giriş yapıldı.
- Drive ana sayfa açıldı; ders listesi, "Ders Oluştur", "Bölüm Ekle", "Koleksiyonlar" ve mevcut son içerikler görüldü.
- "Ders Oluştur" butonu tıklandı, "Tur 4 QA Ders" girildi ve kaydedildi. `functions/v1/sourcebase` 200 döndü.
- Yeni ders detayında "Bölüm Ekle" tıklandı, "Tur 4 QA Bölüm" girildi ve kaydedildi. `functions/v1/sourcebase` 200 döndü.
- Yeni bölüm ekranında "Dosya Yükle" tıklandı. File chooser açıldı.
- Küçük/geçerli PDF dosyası seçildi: `/Volumes/driveand/tur3_live_qa_valid.pdf`.
- PDF seçildikten sonra 35 saniye beklendi.
- Bekleme sonunda bölüm ekranı hâlâ "Bu bölümde henüz dosya yok" gösterdi.
- Network gözleminde PDF seçimi sonrasında `create_upload_session`, storage upload veya `complete_upload` çağrısı görülmedi.
- Mevcut canlı dosya için "Tur 3 Live QA Backend" dersi açıldı, bölüm açıldı, `tur3_live_qa.pdf` dosyasına girildi.
- Dosya listesinde mevcut dosya `İşleniyor` göründü; dosya detayında aynı dosya `Durum: Hata` olarak göründü.
- Arama ekranı açıldı; `tur3_live_qa` araması önceki testte sonuçsuz kalmıştı. Bu turda arama denemesi sırasında ayrı bir koordinat hatası Google OAuth URL'sine götürdü; arama güvenilir biçimde tamamlanamadı.
- Koleksiyonlar ekranı açıldı; üretim olmadığı için sayaçlar 0 ve empty state gösterildi.
- iPhone 14 viewport'ta login başarılı oldu, Drive ana ekranı açıldı.
- Tablet viewport'ta koordinat tabanlı otomasyon login'i tamamlayamadı; tablet için manuel canlı kontrol gerekir.

## 4. Çalışanlar
- E-posta/şifre login çalışıyor.
- Drive ana sayfa açılıyor.
- Ders oluşturma çalışıyor ve oluşturulan ders detayına geçiliyor.
- Bölüm oluşturma çalışıyor ve oluşturulan bölüm ekranına geçiliyor.
- Bölüm ekranında empty state anlaşılır.
- File chooser açılıyor.
- Mevcut dosya satırından dosya detayına girilebiliyor.
- Dosya hata durumundayken üretim engelleniyor ve kullanıcıya "dosyayı yeniden yükleyin" mesajı veriliyor.
- Koleksiyonlar boş durumda yanıltıcı mock göstermiyor; sayaçlar 0.
- iPhone 14 ana Drive ekranı açılıyor.

## 5. Kırılanlar
- Küçük PDF seçilince upload gerçekten başlamıyor gibi görünüyor.
- Upload progress görünmedi.
- `create_upload_session` network çağrısı görülmedi.
- Storage upload network çağrısı görülmedi.
- `complete_upload` network çağrısı görülmedi.
- Upload sonrası dosya bölüm listesine eklenmedi.
- Upload başarısızlığı için kullanıcıya hata, retry veya teknik hata kodu gösterilmedi; ekran sessizce empty state'te kaldı.
- Dosya listesi ve dosya detayı status mapping tutarsız: listede `İşleniyor`, detayda `Durum: Hata`.
- Arama güvenilir biçimde doğrulanamadı; önceki canlı bulguda mevcut dosya/ders aranmasına rağmen sonuç dönmemişti.
- Google ile devam et butonu kullanıcıyı 400 `Unsupported provider: provider is not enabled` hatasına götürebiliyor.
- Tablet viewport login otomasyonla tamamlanamadı; manuel tablet testi gerekli.

## 6. Release blocker
- Var:
- Detay: Drive'ın ana vaadi olan "kullanıcı kendi kaynağını yükler ve üretime geçer" canlıda tamamlanamıyor. PDF seçici açılıyor ama upload progress başlamıyor, `create_upload_session`/storage/`complete_upload` çağrıları görünmüyor, dosya listeye yansımıyor ve kullanıcıya hata/retry sunulmuyor. Bu yüzden kullanıcı kendi PDF kaynağını yükleyip üretime hazır hale getiremiyor.

## 7. Major issue
- Liste/detay status tutarsızlığı kullanıcıyı yanıltıyor: aynı dosya listede `İşleniyor`, detayda `Hata`.
- Upload sessiz başarısız oluyor; kullanıcı ne olduğunu anlayamıyor.
- Arama akışı mevcut kaynak bulunabilirliği açısından güven vermiyor.
- Google OAuth butonu canlıda aktif görünüyor ama provider kapalı olduğu için 400 hatası üretiyor.
- iPhone 14 ekranında Drive açılıyor, ancak alt navigation hero altındaki içeriklerin üzerine çok yaklaşıyor; küçük ekran ergonomisi tekrar kontrol edilmeli.

## 8. Polish issue
- Login ekranında console verbose uyarısı var: password field form içinde değil.
- Flutter semantics metinlerinde bazı CTA'lar çift okunuyor: "Giriş Yap Giriş Yap", "Dosya Yükle Dosya Yükle", "Kaynak Oluştur Kaynak Oluştur".
- Tekrarlanan test dersleri ana sayfada çoğalıyor; canlı QA temizliği veya test datası ayrımı yok.

## 9. Kullanıcı deneyimi kararı
- Kullanıcı bu alanda amacına ulaşabiliyor mu?
- Hayır.
- Neden? Kullanıcı giriş yapabiliyor, Drive'a girebiliyor, ders ve bölüm oluşturabiliyor. Ancak küçük PDF seçildikten sonra upload başlamıyor, progress yok, complete upload yok, dosya listeye eklenmiyor. Kaynak yüklenemediği için dosyadan üretime geçilemiyor.

## 10. Patch gerekiyor mu?
- Evet:
- Gerekirse hangi dosyalar: Drive upload frontend dosyaları (`drive_upload_service_web.dart`, `drive_upload_service_io.dart`, `drive_workspace_screen.dart`, `drive_repository.dart`) ve backend tarafında `create_upload_session` / `complete_upload` canlı log kontrolü.
- Patch önceliği: blocker.

## 11. Kanıt / not
- Console hatası: Kritik runtime/page error yakalanmadı. Verbose uyarı: password field form içinde değil. Bir kullanıcı aksiyonunda Google OAuth provider kapalı olduğu için 400 resource error görüldü.
- Network hatası: Login `auth/v1/token` 200. Ders/bölüm işlemleri `functions/v1/sourcebase` 200. PDF seçimi sonrasında `create_upload_session`, storage upload veya `complete_upload` çağrısı görülmedi. Google OAuth denemesinde `auth/v1/authorize?provider=google` 400 döndü.
- Ekran gözlemi: "Tur 4 QA Ders" oluşturuldu, "Tur 4 QA Bölüm" oluşturuldu, file chooser açıldı, PDF seçildi, 35 saniye sonra ekran hâlâ "Bu bölümde henüz dosya yok" durumundaydı.
- Dosya detayı kanıtı: `tur3_live_qa.pdf` listede `İşleniyor`, detayda `Durum: Hata`; üretim bölümü "Dosya işlenemedi. Bu kaynaktan üretim almak için dosyayı yeniden yükleyin." mesajını gösterdi.
- Manuel test yapılamadıysa nedeni: Testler gerçek canlı URL'de Chrome headless ile yapıldı. Tablet login otomasyonu koordinat nedeniyle tamamlanamadı; tablet için manuel cihaz kontrolü gerekir.
