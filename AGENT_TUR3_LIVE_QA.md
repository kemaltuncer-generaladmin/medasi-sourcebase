# TUR 3 CANLI UX RAPORU - DESIGN RESPONSIVE UX

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: iPhone 14 390x844, tablet 768x1024, desktop 1440x900
- Tarayıcı: Google Chrome headless/CDP
- Tarih/saat: 2026-05-18 05:04:44 +03

## 2. Gerçekten denenen akışlar
- Canlı app shell açıldı; HTTP 200 alındı ve Flutter app boot etti.
- iPhone 14 viewportta login ekranı açıldı.
- Boş login denendi; kullanıcıya “E-posta adresini girmelisin.” validasyonu gösterildi.
- Verilen test hesabı ile giriş yapıldı; canlı uygulama `#/home` Drive ana sayfasına geçti.
- Drive ana sayfa, arama ekranı, Merkezi AI, BaseForce, SourceLab ve Profile ekranları bottom nav üzerinden açıldı.
- Tablet ve desktop viewportta oturum açık durumdaki layout kontrol edildi.
- Console/CDP olayları ve network failure kayıtları kontrol edildi.

## 3. Çalışanlar
- Login canlı hesapla çalışıyor ve kullanıcı Drive ana sayfaya düşüyor.
- Drive ana sayfa açılıyor; ders listesi, ana CTA’lar, empty dosya/koleksiyon mesajları görünüyor.
- Arama ekranı açılıyor; boş sonuç state’i ve filtreler görünüyor.
- Merkezi AI açılıyor; Drive bağlamı boşken kullanıcıya kaynak olmadığı açıklanıyor, chat input görünüyor.
- BaseForce açılıyor; Drive’dan seç / yeni dosya yükle / üretim merkezleri görünür.
- SourceLab açılıyor; kaynak seçimi ve hızlı başlat alanları görünür.
- Profile açılıyor; kullanıcı bilgisi, cüzdan, istatistik ve bağlı-değil ayar state’leri görünüyor.
- Tablet/desktopta nav rail görünüyor; içerik max-width ile kontrol altında kalıyor.

## 4. Kırılanlar
- iPhone 14 Drive ana sayfada ilk ekran içinde “Derslerim” ve altındaki bazı aksiyonlar bottom nav bölgesine çok yakın/arkasında kalıyor; “Tümünü Gör” semantics yüksekliği 5px olarak raporlandı.
- iPhone 14 BaseForce’ta üretim merkezi kartlarının “Aç” butonları ilk viewportta bottom nav altında kalıyor; scroll ile erişilebilir olması muhtemel ama canlı headless testte görünür ilk aksiyon alanı güvenli değil.
- iPhone 14 SourceLab’ta hızlı başlat kartları ve “Başlat” butonları ilk viewport dışında/bottom nav altında kalıyor; kullanıcı ilk ekranda araç başlatma aksiyonunu net göremiyor.
- Kayıt ekranına geçiş headless tıklamada doğrulanamadı; login ekranı görünmeye devam etti. Manuel GUI ile tekrar kontrol gerekir.
- Upload/native file picker canlı headless ortamda doğrulanamadı.

## 5. Release blocker
- Var
- Detay: Mobil iPhone 14’te Drive/BaseForce/SourceLab ana akışlarında kritik alt içerik ve CTA’lar bottom nav güvenli alanına çok yakın veya altında kalıyor. Bu, “mobilde ana akış kullanılamıyorsa tasarım hazır değildir” kriterine göre release blocker riskidir. Login ve Drive’a geçiş çalışıyor.

## 6. Major issue
- Bottom nav içerik ile yarışıyor; bazı scroll içerikleri için alt güvenli padding yetersiz görünüyor.
- Auth butonlarının semantics metni iki kez okunuyor: “Giriş Yap Giriş Yap”, “Hesap Oluştur Hesap Oluştur”.
- SourceLab/BaseForce ilk ekran hiyerarşisi mobilde CTA’ları aşağı itiyor; kullanıcı “başlat” aksiyonunu aramak zorunda kalıyor.
- Store/Mağaza akışı Profile içinde “Mağazaya git” semantics olarak göründü, fakat mağaza ekranı ayrıca doğrulanmadı.

## 7. Polish issue
- Console’da kritik runtime exception görülmedi; Chrome headless kaynaklı CPU rendering warning ve GCM/deprecated endpoint gürültüsü var.
- Password input için Chrome “Password field is not contained in a form” önerisi var; Flutter web semantics kaynaklı, kritik değil.
- Search input’a yazma headless semantics ile net doğrulanamadı; ekran ve empty state açılıyor.
- Login/register formunun gerçek mobil klavye davranışı headless ortamda doğrulanamadı.

## 8. Kullanıcı deneyimi kararı
- Kısmen: Kullanıcı login olup Drive, AI, BaseForce, SourceLab ve Profile alanlarını açabiliyor. Ancak iPhone 14’te bottom nav/scroll güvenliği ve kritik CTA görünürlüğü release öncesi düzeltilmeli.

## 9. Patch gerekiyor mu?
- Evet
- Gereken dosyalar:
  - `lib/features/drive/presentation/widgets/drive_ui.dart`: Workspace scroll bottom padding/safe area standardı.
  - `lib/features/drive/presentation/widgets/sourcebase_bottom_nav.dart`: bottom nav yüksekliği/safe area ve içerik çakışması kontrolü.
  - `lib/features/drive/presentation/screens/drive_home_screen.dart`: mobil ilk viewport hiyerarşisi ve CTA görünürlüğü.
  - `lib/features/baseforce/presentation/screens/baseforce_screen.dart`: mobil üretim merkezi kartlarının alt güvenli alanı.
  - `lib/features/sourcelab/presentation/screens/source_lab_screen.dart`: hızlı başlat kartları ve CTA’lar için mobil scroll/safe padding.
  - `lib/features/auth/presentation/widgets/auth_widgets.dart`: duplicate button semantics polish.

## 10. Kanıt / not
- Console hatası: Kritik app runtime exception gözlenmedi. Kayıtlar: Flutter bootstrap debug, `WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1`, Chrome password field recommendation.
- Network hatası: Bir adet `net::ERR_ABORTED`; app boot/login akışını bozmadı.
- Ekran gözlemi: Login başarılı; `/home` Drive açıldı. Bottom nav iPhone 14’te 767-825 bandında; Drive/BaseForce/SourceLab içerikleri bu banda ve altına taşıyor.
- Manuel test yapılamadıysa nedeni: Test Chrome headless/CDP ile yapıldı; gerçek GUI/ekran görüntüsü, mobil sanal klavye ve native file picker/upload manuel doğrulaması yapılamadı.
