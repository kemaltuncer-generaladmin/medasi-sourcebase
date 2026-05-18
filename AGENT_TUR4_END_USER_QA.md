# TUR 4 SON KULLANICI QA RAPORU - DESIGN RESPONSIVE UX

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: iPhone 14 390x844, tablet 768x1024, desktop 1440x900
- Tarayıcı: Google Chrome headless/CDP
- Tarih/saat: 2026-05-18 05:54:35 +03

## 2. Son kullanıcı senaryosu
Kullanıcı SourceBase’e girip Drive’da kaynaklarını görmek/yüklemek, ders veya dosya detayına geçmek, bu kaynaklardan Central AI/BaseForce/SourceLab ile öğrenme çıktısı üretmek, sonuçları yönetmek ve profil/mağaza/çıkış akışını anlayarak kullanmak istiyor.

## 3. Gerçekten denenen akışlar
- Canlı URL iPhone 14 viewportta açıldı; login ekranı render oldu.
- Boş login denendi; “E-posta adresini girmelisin.” validasyonu görüldü.
- Gerçek test hesabıyla giriş yapıldı; `/home` Drive ekranına geçildi.
- Drive ana CTA “Kaynak Oluştur” tıklandı; Chrome `Page.fileChooserOpened` olayı geldi.
- Drive ana sayfada ders listesi aşağı scroll edildi; “Tur 3 Live QA Backend” ders satırı görünür alana getirilmeye çalışıldı.
- Drive arama açıldı; `anatomi` metni girildi; 0 sonuç / filtre / temizle empty state’i görüldü.
- Central AI tabı açıldı; Drive bağlamında mevcut PDF “İşleniyor” olarak göründü.
- BaseForce tabı açıldı; “Drive’dan Seç”, “Yeni Dosya Yükle”, “Tümünü Gör” ve “Aç” butonları gözlemlendi.
- SourceLab tabı açıldı; “Kaynak Seç” tıklandı; Drive kaynak seçici modalı açıldı.
- Profile tabı açıldı; profil, cüzdan ve ayar state’leri gözlemlendi.
- Cüzdan / “Mağazaya git” alanı tıklandı; görünür state değişimi olmadı.
- Profil ekranında logout/çıkış aranıp tıklandı; görünür “Çıkış” aksiyonu bulunamadı.
- Tablet ve desktop viewportlarda profil/nav rail temel görünüm kontrol edildi.
- Console, network response ve runtime error olayları kontrol edildi.

## 4. Çalışanlar
- Canlı site açılıyor; app shell ve Flutter uygulaması boot ediyor.
- Login gerçek hesapla çalışıyor ve Drive ana sayfaya geçiyor.
- Boş login validasyonu kullanıcı dostu Türkçe mesaj gösteriyor.
- Drive ana sayfa açılıyor; dersler ve mevcut kaynak sayıları görünüyor.
- Upload CTA gerçek dosya seçici açıyor; bu, butonun fake olmadığını gösteriyor.
- Search ekranı açılıyor; arama metni girilince boş sonuç state’i ve filtreler görünüyor.
- Central AI ekranı açılıyor; Drive bağlamı ve mevcut kaynak durumu görünüyor.
- SourceLab kaynak seçici modalı açılıyor; mevcut PDF kaynak seçilebilir listeleniyor.
- Tablet/desktopta nav rail görünüyor; içerik max-width içinde kalıyor ve ürün hissi korunuyor.
- Console’da kritik Flutter runtime exception görülmedi.
- Network tarafında 400/500/502/503 response gözlenmedi.

## 5. Kırılanlar
- iPhone 14 Drive’da ders satırları bottom nav arkasında kalıyor; “Tur 3 Live QA Backend” satırı scroll sonrası yalnızca 11px yükseklikle görülebildi, bu yüzden ders/dosya detayına güvenilir şekilde girilemedi.
- iPhone 14 BaseForce’ta “Aç” butonları y=936’da, viewport ve bottom nav altında kalıyor; ilk anlamlı viewportta erişilebilir değil.
- iPhone 14 SourceLab’ta “Başlat” butonları y=1020’de, viewport dışında ve bottom nav altında kalıyor; hızlı başlat aksiyonu gerçek kullanıcı için gizli kalıyor.
- SourceLab kaynak seçicide mevcut PDF “0 KB • İşleniyor” durumunda kaldı; bu kaynakla üretim başlatılabilir durumda görünmüyor.
- Central AI’da mesaj gönderme canlı headless etkileşimde doğrulanamadı; input görünüyor ama gönder aksiyonu semantics içinde yakalanmadı.
- Store / mağaza akışı cüzdan kartından görünür şekilde açılmadı.
- Logout / çıkış butonu profil ekranında görünür/erişilebilir bulunamadı.
- Auth primary button semantics canlı deployda hâlâ iki kez okunuyor: “Giriş Yap Giriş Yap”, “Hesap Oluştur Hesap Oluştur”.

## 6. Release blocker
- Var:
- Detay:
  - Mobil iPhone 14’te BaseForce ve SourceLab kritik üretim CTA’ları bottom nav altında kalıyor.
  - Drive ders/dosya detayına mobilde güvenilir geçiş yapılamadı; ders satırı bottom nav alanında sıkışıyor.
  - Kaynak seçici mevcut PDF’i “İşleniyor / 0 KB” gösteriyor; kullanıcı kaynak üretimine sağlıklı devam edemiyor.
  - Store ve logout akışları canlı testte görünür/erişilebilir doğrulanamadı.

## 7. Major issue
- Bottom nav içerik üstüne biniyor; scroll sonu safe padding canlı sürümde yeterli değil.
- Drive ana sayfada kritik liste item’ları nav altında kaldığı için gerçek kullanıcı ders/dosya detayına ulaşmakta zorlanır.
- BaseForce/SourceLab ana ekranlarında hero ve üst içerik kritik üretim aksiyonlarını ilk anlamlı viewport dışına itiyor.
- SourceLab kaynak seçici modalı açılıyor ama seçilebilir kaynak “İşleniyor” olduğu için üretim zinciri kullanıcı açısından tamamlanmıyor.
- Profile cüzdan/store CTA’sı state değiştirmedi; kullanıcı mağazaya ulaştığını anlayamıyor.

## 8. Polish issue
- Auth butonları erişilebilirlik metninde duplicate okunuyor.
- Chrome console’da `WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1` var; headless ortama bağlı, kullanıcı blocker değil.
- Chrome “[DOM] Password field is not contained in a form” önerisi var; Flutter web semantics kaynaklı polish.
- Türkçe metinler genel olarak kart dışına taşmadı, ancak mobilde bazı kartlar/CTA’lar viewport dışına fazla erken itiliyor.

## 9. Kullanıcı deneyimi kararı
- Kullanıcı bu alanda amacına ulaşabiliyor mu?
- Kısmen
- Neden?
  Login ve ana modüllere erişim çalışıyor. Ancak ana ürün vaadi olan “kaynağı Drive’da yönet, detayına gir, üretim başlat, sonucu yönet” zinciri iPhone 14’te bottom nav/scroll güvenliği ve işleniyor kaynak durumu nedeniyle kesiliyor. Tablet ve desktop daha okunabilir, fakat profile/store/logout zinciri de canlı testte tamamlanamadı.

## 10. Patch gerekiyor mu?
- Evet:
- Gerekirse hangi dosyalar:
  - `lib/features/drive/presentation/widgets/sourcebase_bottom_nav.dart`
  - `lib/features/drive/presentation/widgets/drive_ui.dart`
  - `lib/features/drive/presentation/screens/drive_home_screen.dart`
  - `lib/features/baseforce/presentation/screens/baseforce_screen.dart`
  - `lib/features/sourcelab/presentation/screens/source_lab_screen.dart`
  - `lib/core/design_system/buttons/sb_primary_button.dart`
  - `lib/core/design_system/buttons/sb_secondary_button.dart`
  - Profile/store/logout erişimi için ilgili profile/store ekran dosyaları ayrıca kontrol edilmeli.
- Patch önceliği: blocker

## 11. Kanıt / not
- Console hatası: Kritik runtime exception yok. Gözlenenler: Flutter bootstrap debug, CPU-only rendering warning, password field form önerisi.
- Network hatası: Kritik 4xx/5xx response gözlenmedi. `BAD_RESPONSES []`.
- Ekran gözlemi:
  - Drive `Kaynak Oluştur` görünür ve file chooser açıyor.
  - Drive ders satırı scroll sonrası nav bölgesinde sıkışıyor.
  - BaseForce `Aç` butonları iPhone 14’te y=936, viewport dışında.
  - SourceLab `Başlat` butonları iPhone 14’te y=1020, viewport dışında.
  - SourceLab kaynak seçici modalı dosyayı “0 KB • İşleniyor” gösteriyor.
  - Tablet/desktop nav rail ürün gibi duruyor; içerik max-width içinde.
- Manuel test yapılamadıysa nedeni:
  Test Chrome headless/CDP ile yapıldı. Gerçek iOS klavye, native file picker sonrası dosya seçimi ve gerçek cihaz dokunma hissi manuel cihazda ayrıca doğrulanmalı. Headless testte file chooser açıldığı kanıtlandı, fakat gerçek dosya seçilip upload progress/success tamamlanması yapılmadı.
