# SCREEN_REVIEW_GUIDE.md — SourceBase İnsan Gözüyle Ekran İnceleme Kılavuzu

Bu dosya, SourceBase ekranlarının insan gözüyle nasıl değerlendirileceğini anlatır.

Opencode Go, tasarım patch'i yapmadan önce ilgili ekranı bu kontrol listelerine göre incelemelidir.

---

# 1. Genel İnceleme Soruları

Her ekran için şu sorular sorulur:

## 1.1 İlk İzlenim

- Bu ekran güven veriyor mu?
- Premium hissettiriyor mu?
- Tıp öğrencisi bu ekranı kullanmak ister mi?
- Ekran ciddi bir ürün gibi mi?
- Yoksa demo/template gibi mi?

## 1.2 Ana Aksiyon

- Kullanıcı bu ekranda ne yapacağını 1 saniyede anlıyor mu?
- Ana buton net mi?
- İkincil butonlar ana aksiyonu boğuyor mu?
- CTA doğru yerde mi?
- Başparmakla erişilebilir mi?

## 1.3 Görsel Hiyerarşi

- En önemli bilgi ilk bakışta görünüyor mu?
- Başlık, açıklama, kart, status, buton dengesi iyi mi?
- Her şey aynı önemde mi görünüyor?
- Gereksiz badge/ikon/metin var mı?

## 1.4 Sıkışıklık

- Kartlar birbirine yakın mı?
- Metinler küçük mü?
- Butonlar dar mı?
- Bottom nav içerik kapatıyor mu?
- Scroll doğal mı?
- Tek ekrana fazla şey sıkıştırılmış mı?

## 1.5 State Kalitesi

- Empty state var mı?
- Loading state güven veriyor mu?
- Error state anlaşılır mı?
- Processing state kullanıcıyı bilgilendiriyor mu?
- Disabled state açık mı?

## 1.6 Mobil Ergonomi

- Safe area doğru mu?
- Bottom CTA nav'a çarpıyor mu?
- Header çok mu uzun?
- Modallar/sheetler sıkışıyor mu?
- Klavye açılınca alan bozulur mu?

---

# 2. Drive Home İnceleme

Drive Home SourceBase'in en kritik ekranıdır.

## 2.1 Kullanıcı Beklentisi

Kullanıcı burada şunu görmek ister:

```txt
Kaynaklarım nerede?
Yeni kaynak nasıl yüklerim?
Hangi dosyalar hazır?
Hangilerinde hata var?
Hazır dosyadan ne üretebilirim?
```

## 2.2 Kontrol Listesi

- Header kısa mı?
- Upload CTA güçlü mü?
- Dosya listesi okunabilir mi?
- File status net mi?
- Hazır olmayan dosyalar üretime uygun gibi görünmüyor mu?
- Empty state yönlendirici mi?
- Error state teknik değil mi?
- Search/filter varsa ekranı boğmuyor mu?
- Bottom nav dosya kartlarını kapatmıyor mu?

## 2.3 Yaygın Sorunlar

- Dosya kartları çok sıkışık
- Status badge belirsiz
- Upload butonu zayıf
- Empty state sıradan
- Hata mesajı teknik
- Processing dosyalar hazır gibi görünüyor
- Dosya adı taşıyor
- CTA nav altında kalıyor

## 2.4 İdeal Drive Patch

İlk patch'te hedeflenebilir:

- Header sadeleştir
- Upload CTA'yı güçlendir
- File card padding artır
- Status badge tasarımını netleştir
- Ready/processing/error/unsupported metinlerini iyileştir
- Empty state'e güçlü yönlendirme ekle
- Bottom padding/safe area düzelt

---

# 3. Upload / Processing İnceleme

## 3.1 Kullanıcı Beklentisi

Kullanıcı şunu bilmek ister:

```txt
Dosyam yüklendi mi?
Şimdi ne oluyor?
Ne kadar beklemeliyim?
Hata varsa ne yapmalıyım?
```

## 3.2 Kontrol Listesi

- Upload progress anlaşılır mı?
- Processing state açık mı?
- Dosya tipi ve adı görünüyor mu?
- Hata olursa ne yapılacağı belli mi?
- Upload sonrası kullanıcı kayboluyor mu?
- "Hazır olduğunda kullanabilirsin" hissi var mı?

## 3.3 İyi Metinler

```txt
Kaynak yükleniyor
Dosyan güvenli şekilde aktarılıyor.

Kaynak işleniyor
Metin çıkarılıyor. Hazır olduğunda üretim için kullanabilirsin.

Kaynak hazır
Bu dosyadan çalışma çıktıları üretebilirsin.
```

---

# 4. BaseForce Home İnceleme

## 4.1 Kullanıcı Beklentisi

Kullanıcı şunu anlamalı:

```txt
Kaynağımı seçtim.
Hangi çalışma materyalini üretebilirim?
Başlatmak için ne yapmalıyım?
```

## 4.2 Kontrol Listesi

- Kaynak seçimi görünür mü?
- Kaynak seçilmemişse ne yapılacağı belli mi?
- Üretim kartları net mi?
- Flashcard/Soru/Özet önceliği açık mı?
- Disabled/yakında state düzgün mü?
- MC maliyeti varsa net mi?
- Üret butonu güçlü mü?
- Çok fazla seçenek kullanıcıyı boğuyor mu?

## 4.3 Yaygın Sorunlar

- Her üretim tipi aynı önemde
- Kaynak seçimi gizli
- Üret butonu zayıf
- Kart açıklamaları uzun
- Disabled state ucuz görünüyor
- Ekran liste çöplüğüne dönüyor

---

# 5. Flashcard Factory İnceleme

## 5.1 Kullanıcı Beklentisi

Kullanıcı şunu ister:

```txt
Bu kaynaktan kaç flashcard üretilecek?
Hangi kalite/ayar kullanılacak?
Başlatınca ne olacak?
```

## 5.2 Kontrol Listesi

- Seçili kaynak net mi?
- Flashcard sayısı anlaşılır mı?
- Ayarlar fazla karmaşık mı?
- Üret butonu net mi?
- Hata durumunda kaynak problemi açıklanıyor mu?
- Processing/failed source seçilemiyor mu?

## 5.3 İdeal Davranış

- Hazır kaynak seçiliyse üretime izin ver
- Hazır olmayan kaynakta CTA disable
- Error/unsupported kaynakta açıklama göster
- Üretim başladıktan sonra loading state göster
- Sonuç gelince Result Detail'e taşı

---

# 6. Generation Loading İnceleme

## 6.1 Kullanıcı Beklentisi

Kullanıcı şunu bilmek ister:

```txt
İşlem gerçekten başladı mı?
Sistem ne yapıyor?
Sonuç nerede görünecek?
```

## 6.2 Kontrol Listesi

- Loading sonsuz spinner gibi mi?
- Aşamalar net mi?
- Kullanıcı geri çıkarsa ne olur?
- Hata mesajı hazır mı?
- Provider hatası teknik gösteriliyor mu?
- Loading ekranı premium mu?

## 6.3 İyi Aşama Metinleri

```txt
Kaynak analiz ediliyor
Önemli noktalar ayrıştırılıyor
Flashcard yapısı hazırlanıyor
Sonuç oluşturuluyor
```

---

# 7. Result Detail İnceleme

## 7.1 Kullanıcı Beklentisi

Kullanıcı şunu ister:

```txt
Çıktıyı rahat okuyayım.
Kaydedeyim.
Kopyalayayım.
Gerekirse yeniden üreteyim.
```

## 7.2 Kontrol Listesi

- Sonuç okunabilir mi?
- Kartlar/başlıklar düzenli mi?
- Kopyala/kaydet/yeniden üret net mi?
- Uzun içerik mobilde rahat mı?
- Kaynak ilişkisi belli mi?
- Boş sonuçta iyi hata var mı?

## 7.3 Yaygın Sorunlar

- Çok uzun paragraf
- Aksiyonlar görünmez
- Kartlar sıkışık
- Başlık yok
- Doğru/yanlış cevap ayrımı belirsiz
- Markdown gibi ham çıktı gösteriliyor

---

# 8. Empty State İnceleme

## 8.1 Kontrol Listesi

- Empty state neden boş olduğunu söylüyor mu?
- Sonraki adımı gösteriyor mu?
- Ana CTA var mı?
- Ürün kalitesini düşürmüyor mu?
- “Hiç veri yok” gibi kuru değil mi?

## 8.2 İyi Örnek

```txt
Henüz kaynak yok
PDF, PPTX veya DOCX yükleyerek çalışma materyali üretmeye başlayabilirsin.

[İlk kaynağını yükle]
```

---

# 9. Error State İnceleme

## 9.1 Kontrol Listesi

- Teknik hata gizlenmiş mi?
- Kullanıcı ne yapacağını anlıyor mu?
- Tekrar dene var mı?
- Farklı dosya önerisi var mı?
- Hata ciddi ama panik yaratmıyor mu?

## 9.2 İyi Örnekler

```txt
Dosya işlenemedi
Bu dosyadan okunabilir metin çıkarılamadı. Farklı bir PDF veya DOCX deneyebilirsin.

Eski PPT desteklenmiyor
Lütfen dosyayı PPTX olarak dışa aktar ve tekrar yükle.
```

---

# 10. Patch Önceliklendirme

Her sorun şu öncelikle işaretlenir:

## P0

Teslimi veya ana akışı bozar.

Örnek:

- upload CTA görünmüyor
- result ekranı okunmuyor
- bottom nav ana butonu kapatıyor
- ready olmayan dosya üretilebilir görünüyor

## P1

Kaliteyi ciddi düşürür.

Örnek:

- dosya kartları çok sıkışık
- status badge belirsiz
- empty/error state kötü
- ana aksiyon zayıf

## P2

Sonradan cilalanabilir.

Örnek:

- mikro spacing
- ikon değişimi
- hafif animasyon
- küçük metin iyileştirmesi

---

# 11. Ekran Rapor Formatı

Her inceleme şu formatta yapılmalıdır:

```md
## Ekran: Drive Home

### İlk İzlenim
...

### En Büyük Sorun
...

### Kullanıcı Riski
...

### Korunması Gerekenler
...

### Düzeltilmesi Gerekenler
1. ...
2. ...
3. ...

### Öncelik
P0/P1/P2

### İlk Küçük Patch
...

### Dokunulacak Dosyalar
- ...
```

---

# 12. Son İlke

İyi tasarım, kullanıcının düşünme yükünü azaltır.

SourceBase ekranları şunu başarmalı:

```txt
Kullanıcı ne yapacağını anlamak için uğraşmamalı.
```
