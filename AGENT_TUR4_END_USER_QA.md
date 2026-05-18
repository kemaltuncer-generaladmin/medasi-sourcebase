# TUR 4 SON KULLANICI QA RAPORU - PROFILE + STORE

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr / şifre sağlandı, raporda yazılmadı
- Cihaz/viewport: iPhone 14 benzeri 390x844 ve headless Chrome 500x757; tablet 834x1194 ve desktop 1440x900 için giriş ekranı temel görünüm kontrolü
- Tarayıcı: Google Chrome 148.0.7778.168 headless, Playwright CLI 1.58.0, curl
- Tarih/saat: 2026-05-18 05:48:19 +03

## 2. Son kullanıcı senaryosu
Kullanıcı SourceBase'e giriş yapıp kim olduğunu, hesabının hangi e-posta ile açık olduğunu, profilinin tamamlanıp tamamlanmadığını, cüzdan/MC/hak durumunu, mağazadaki paketleri, satın alma durumunu, ayarlar/destek/gizlilik bilgilerini ve çıkış akışını anlamak istiyor.

## 3. Gerçekten denenen akışlar
- Canlı URL açıldı; `/`, `main.dart.js`, `flutter_bootstrap.js` ve manifest endpoint'leri erişilebilir kontrol edildi.
- iPhone 14, tablet ve desktop viewport'ta giriş ekranı render edildi.
- Test hesabı ile e-posta/şifre alanları dolduruldu ve `Giriş Yap` butonuna basıldı.
- Login sonrası `#/home` içinde Drive ana ekranı açıldı; bottom nav'dan `Profil ve Ayarlar` sekmesine geçildi.
- Profil kartı, kullanıcı adı/e-posta/fakülte/bölüm/profil tamamlandı state'i, istatistikler ve cüzdan metinleri okundu.
- `Profili düzenle` butonuna basıldı; `#/profile-setup` akışına geçtiği görüldü, geri dönüldü.
- Cüzdan kartından mağazaya geçildi; paket listesi ve `Ödeme Linki Al` butonları görüldü.
- Bir paket için `Ödeme Linki Al` butonuna basıldı; backend `400` döndü ve UI hata state'i gösterdi.
- Ayarlar alanı aşağı kaydırıldı; profil bilgileri, bildirim, güvenlik, görünüm, dil, gizlilik/destek, hesap silme, hakkında ve çıkış alanları görüldü.
- `Güvenlik ve Şifre` bilgilendirme dialog'u açılıp kapatıldı.
- `Çıkış Yap` butonuna basıldı; onay dialog'unda tekrar `Çıkış Yap` seçildi ve uygulama `#/login` ekranına döndü.

## 4. Çalışanlar
- Login canlıda başarılı: giriş sonrası `#/home` açıldı.
- Profil bilgisi doğru ve anlaşılır görünüyor: `kemal.tuncer`, `kemal.tuncer@medasi.com.tr`, `Kırşehir Ahi Evran Üniversitesi`, `Tıp`, `Profil tamamlandı`.
- Profil metninde `null`, `undefined` veya `NaN` gözlenmedi.
- İstatistikler sayısal ve güvenli görünüyor: Ders 8, Dosya 1, Üretim 0, Koleksiyon 0.
- Cüzdan güvenli görünüyor: `100.62 MC`, `Ek hak yok`.
- Mağaza paketleri listeliyor: Aylık, Haftalık, 50 MC, 20 MC, 10 MC; fiyatlar TRY olarak görünüyor.
- Satın alma butonu fake success üretmedi; ödeme başlatılamayınca kullanıcıya hata gösterdi.
- Ayarlar boş toggle'lardan oluşmuyor; bağlı olmayan bildirim/görünüm/dil state'leri açıkça anlatılıyor.
- Gizlilik/destek, hesap silme ve hakkında alanları görünür.
- Logout çalışıyor: onay dialog'u çıktı, onay sonrası `#/login` ekranına döndü.

## 5. Kırılanlar
- Mağazada `Ödeme Linki Al` aksiyonu `https://medasi.com.tr/functions/v1/sourcebase` için `400` döndürdü.
- Ödeme backend'i link başlatamadığı için kullanıcı gerçek satın alma akışını tamamlayamıyor.
- Privacy/support/account deletion alanları canlıda ayrı dış bağlantı veya gerçek destek formu gibi çalıştırılarak doğrulanmadı; görünen hali bilgilendirme state'i.

## 6. Release blocker
- Var/Yok: Yok
- Detay: Profile/Store tarafında fake purchase success yok, logout çalışıyor, profil/cüzdan kullanıcıyı yanıltacak `null/NaN/undefined` göstermiyor. Ancak ödeme linki başlatma `400` hatası Major issue olarak duruyor; gerçek satış beklenen release kapsamındaysa Backend/IAP tarafında release blocker'a yükseltilmeli.

## 7. Major issue
- Satın alma başlatılamıyor: `Ödeme Linki Al` backend isteği `400` dönüyor ve kullanıcı ödeme linkine ulaşamıyor.
- App Store hazırlığı için privacy/support/account deletion alanları görünür olsa da canlıda gerçek link/form akışı olarak doğrulanmadı.

## 8. Polish issue
- Console'da Chrome/Flutter web uyarısı var: CPU-only rendering fallback ve password field form içinde değil uyarısı.
- Login ekranında bazı semantics metinleri tekrar ediyor: `Giriş Yap Giriş Yap`, `Hesap Oluştur Hesap Oluştur`.
- Mobil profilde bazı içerikler bottom nav altında kalmadan scroll ile erişiliyor; kullanılabilir, ama yoğun ayarlar alanı uzun.

## 9. Kullanıcı deneyimi kararı
- Kullanıcı bu alanda amacına ulaşabiliyor mu?
- Kısmen
- Neden? Kullanıcı hesabını, profil durumunu, cüzdanını, paketleri, ödeme hatasını ve çıkışı anlayabiliyor. Satın alma gerçek ödeme/link aşamasına geçemediği için mağaza tarafında amaç tamamlanmıyor.

## 10. Patch gerekiyor mu?
- Evet/Hayır: Evet
- Gerekirse hangi dosyalar: Büyük olasılıkla backend ödeme action'ı veya IAP/ödeme entegrasyonu; bu turda kod patch yapılmadı. Flutter tarafında gerekirse ödeme hata mesajı ve support yönlendirmesi için `lib/features/profile/presentation/screens/profile_screen.dart`.
- Patch önceliği: major

## 11. Kanıt / not
- Console hatası: `Failed to load resource: the server responded with a status of 400 ()` ödeme denemesi sonrası görüldü. Ayrıca `WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1` ve `[DOM] Password field is not contained in a form` uyarıları görüldü.
- Network hatası: `https://medasi.com.tr/functions/v1/sourcebase` ödeme linki başlatma denemesinde `400` döndü. Ana canlı URL ve JS asset'leri `HTTP/2 200`.
- Ekran gözlemi: Login ekranı mobil/tablet/desktop'ta render oldu. Profile canlıda kullanıcı adı/e-posta/fakülte/bölüm/cüzdan gösterdi. Store paketleri listeledi. Satın alma fake başarı vermedi, hata gösterdi. Logout onay sonrası login'e döndü.
- Manuel test yapılamadıysa nedeni: GUI tarayıcı yoktu; testler headless Chrome DevTools ve Playwright screenshot ile yapıldı. Profile/Store içi etkileşimler canlı oturumda gerçek test hesabıyla tamamlandı.
