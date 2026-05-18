# TUR 3 CANLI UX RAPORU - DRIVE + UPLOAD

## 1. Test ortamı
- URL: https://sourcebase.medasi.com.tr
- Test hesabı: kemal.tuncer@medasi.com.tr
- Cihaz/viewport: Desktop 1440x900, iPhone 14 390x844, tablet denemesi 820x1180
- Tarayıcı: Google Chrome via Playwright headless
- Tarih/saat: 2026-05-18 05:20 +03 civarı

## 2. Gerçekten denenen akışlar
- Canlı site açıldı; login ekranı render oldu.
- Test hesabıyla gerçek giriş yapıldı; auth isteği 200 döndü ve Drive ana sayfa açıldı.
- Drive ana sayfada dersler, son yüklemeler ve koleksiyon empty state gözlendi.
- "Ders Oluştur" açıldı; boş isim validasyonu görüldü.
- "Kardiyoloji Test" dersi oluşturuldu; backend function 200 döndü ve ders detayına geçildi.
- Ders detayında "Bölüm Ekle" açıldı.
- "Akut Koroner Sendrom" bölümü oluşturuldu; backend function 200 döndü ve bölüm ekranına geçildi.
- Bölüm ekranında "Dosya Yükle" tıklandı; dosya seçici açıldı.
- Küçük test PDF seçildi; sonra daha geçerli 13 KB PDF ile ikinci kez denendi.
- Mevcut "Tur 3 Live QA Backend" dersindeki mevcut PDF satırına girildi; bölüm listesi ve dosya detayı kontrol edildi.
- Drive arama ekranı açıldı; sonuçsuz arama empty state görüldü.
- Koleksiyonlar ekranı açıldı; üretim olmadığı durumda empty state ve sayaçlar görüldü.
- iPhone 14 viewport ile giriş ve Drive ana sayfa görüntülendi.

## 3. Çalışanlar
- Login yapılabildi.
- Drive açıldı ve loading sonrası içerik geldi.
- Ders oluşturma çalıştı; boş isim validasyonu çalıştı.
- Bölüm oluşturma çalıştı.
- Bölüm/klasör ekranı açıldı, empty state anlaşılır.
- Dosya seçici açıldı.
- Dosya detay ekranı mevcut dosya için açıldı.
- Hatalı/işlenememiş dosyada üretim engeli mesajı gösterildi.
- Koleksiyonlar boş state'i gerçek/güvenli görünüyor.
- Console'da kırmızı runtime/page error yakalanmadı.

## 4. Kırılanlar
- Upload canlı testinde takıldı: PDF seçildikten sonra progress başlamadı, dosya listeye eklenmedi.
- PDF seçiminden sonra gözlenen network isteklerinde create_upload_session, storage upload veya complete_upload sonucu görünmedi.
- Bölüm ekranı aynı empty state'te kaldı; kullanıcı upload'ın başladığını, bittiğini veya hata verdiğini göremiyor.
- Mevcut PDF listede "İşleniyor" görünürken dosya detayında "Durum: Hata" görünüyor; status tutarsız.
- Aramada "tur3_live_qa" ve "Kardiyoloji" denemelerinde sonuç çıkmadı; mevcut dosya/ders bulunamadı.
- Tablet viewport login akışı otomasyon koordinatı nedeniyle tamamlanamadı; manuel tablet testi gerekli.

## 5. Release blocker
- Var
- Detay: Kullanıcı PDF seçebiliyor ancak canlı upload progress/session/complete zinciri gözlenmedi ve seçilen dosya listeye yansımadı. Drive'ın ana vaadi olan kaynak yükleme canlıda tamamlanamıyor.

## 6. Major issue
- Dosya status'u liste ve detay arasında tutarsız: liste "İşleniyor", detay "Hata".
- Arama mevcut Drive içeriğini bulmuyor gibi davrandı.
- iPhone 14 ana sayfada bottom nav alt içerik üzerine yaklaşıyor/kaplıyor; alt kartlar kısmen görünür durumda.

## 7. Polish issue
- Login ekranında console verbose uyarısı var: password field form içinde değil.
- Flutter web accessibility metninde bazı butonlar iki kez okunuyor: "Giriş Yap Giriş Yap", "Dosya Yükle Dosya Yükle".

## 8. Kullanıcı deneyimi kararı
- Kısmen: Kullanıcı giriş yapıp Drive'a girebiliyor, ders ve bölüm oluşturabiliyor. Ancak canlı kaynak yükleme tamamlanamadığı için kullanıcı kendi kaynağını yükleyip üretime hazır hale getiremiyor.

## 9. Patch gerekiyor mu?
- Evet
- Gereken dosyalar: Drive upload akışının frontend dosyaları ve gerekirse backend sourcebase function. Frontend tarafında dosya seçimi sonrası upload session/progress/error state tetiklenmiyor gibi görünüyor. Backend tarafında create_upload_session/complete_upload çağrısı canlıda hiç görünmediği için backend ajanının da endpoint/log kontrolü yapması gerekiyor.

## 10. Kanıt / not
- Console hatası: Runtime/page error yok. Sadece debug "Injecting script tag" ve verbose "[DOM] Password field is not contained in a form" uyarısı görüldü.
- Network hatası: Auth token 200, sourcebase function 200. PDF seçiminden sonra upload session/storage/complete network akışı gözlenmedi.
- Ekran gözlemi: Login başarılı; Drive ana sayfa açıldı; "Kardiyoloji Test" ve "Akut Koroner Sendrom" oluşturuldu; bölümde PDF seçimi sonrası liste "Bu bölümde henüz dosya yok" olarak kaldı.
- Manuel test yapılamadıysa nedeni: Canlı test otomasyonla yapıldı. İlk aşamada yerel sistem diski doluluğu Playwright'ı engelledi, cache/temp temizliği sonrası Chrome ile canlı test yapıldı. Tablet akışı koordinat tabanlı otomasyon nedeniyle doğrulanamadı; manuel tablet testi gerekli.
