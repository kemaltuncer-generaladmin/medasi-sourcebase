# DESIGN_SYSTEM.md — SourceBase Premium Mobile Design System

Bu dosya SourceBase'in kullanıcıya görünen tasarım dilini belirler.

Opencode Go, tasarım görevlerinde bu dosyayı bağlayıcı kabul etmelidir.

---

# 1. Marka Hissi

SourceBase şu hissi vermelidir:

```txt
Klinik
Güvenilir
Sade
Akıllı
Premium
Ferah
Tıp öğrencisine uygun
Çalışmaya odaklı
```

SourceBase şu hissi vermemelidir:

```txt
Oyuncak gibi
Neon
Robotik
Kripto uygulaması gibi
Aşırı gradientli
Yapay zeka şablonu gibi
Sıkışık
Ucuz SaaS template'i gibi
```

---

# 2. Ürün Cümlesi

SourceBase'in kullanıcıya hissettirmesi gereken temel cümle:

```txt
Kaynağını yükle, sistem sana düzenli ve kaliteli çalışma materyali hazırlasın.
```

Bu cümle tasarım kararlarının merkezidir.

Her ekran bu akışı desteklemelidir:

```txt
Kaynak yükle
→ Kaynağın hazır olduğunu gör
→ Çalışma çıktısı üret
→ Sonucu rahatça kullan
```

---

# 3. Görsel Atmosfer

## 3.1 Zemin

- kırık beyaz
- çok açık gri
- temiz, sessiz yüzeyler
- göz yormayan kontrast

Kaçın:

- saf parlak beyaz üstüne agresif neon
- yoğun arka plan desenleri
- ağır karanlık tema hissi
- her yerde blur/cam efekti

## 3.2 Metin Rengi

- derin lacivert
- mürekkep tonu
- siyaha yakın ama daha yumuşak
- ikincil metinlerde gri-mavi

## 3.3 Aksan

- medikal teal
- sakin mavi-yeşil
- yumuşak cyan
- küçük dozda premium mavi

Aksan rengi anlam için kullanılır, süs için değil.

---

# 4. Tipografi

## 4.1 Başlık

Başlıklar kısa olmalı.

İyi:

```txt
Kaynakların
Bugün ne üretelim?
Hazır kaynaklar
Flashcard Factory
Soru Fabrikası
Sonuç hazır
```

Kötü:

```txt
Yapay zeka destekli süper gelişmiş kaynak dönüştürme deneyimi
Kaynaklarını sihirli şekilde geleceğe taşı
```

## 4.2 Açıklama

Açıklama metni:

- kısa
- yönlendirici
- sakin
- insan gibi
- teknik jargonsuz

Örnek:

```txt
PDF, PPTX veya DOCX yükleyerek çalışma materyali üretmeye başlayabilirsin.
```

## 4.3 Hata Metni

Hata metni kullanıcıyı suçlamaz.

Kötü:

```txt
extract failed
unsupported file
unknown error
```

İyi:

```txt
Bu PDF görüntü tabanlı görünüyor. Metin çıkarılamadı.
Eski PPT formatı desteklenmiyor. Lütfen dosyayı PPTX olarak dışa aktar.
Dosya işlenirken sorun oluştu. Farklı bir dosya deneyebilirsin.
```

---

# 5. Spacing ve Yerleşim

Mobilde ferahlık zorunludur.

Kurallar:

- ekran kenar boşluğu yeterli olmalı
- kartlar birbirine yapışmamalı
- butonlar başparmakla rahat basılmalı
- status badge metne sıkışmamalı
- section araları net olmalı
- tek ekrana her şeyi sığdırmaya çalışma

## 5.1 Minimum Hedefler

- dış padding: 16-24 arası
- kart iç padding: 14-20 arası
- kart arası boşluk: 12-16 arası
- section arası boşluk: 20-32 arası
- buton yüksekliği: rahat dokunulabilir olmalı

## 5.2 Yasaklar

- 8px altı sıkışık kart padding
- aynı satırda 3 uzun metin + badge + ikon
- bottom nav altında kalan CTA
- ekranda aynı anda 7-8 eşit önemde kart
- tek satıra sığmayan ama kesilen dosya adı

---

# 6. Kart Sistemi

SourceBase'te kartlar ana bilgi taşıyıcısıdır.

Kart kalitesi ürün kalitesidir.

## 6.1 İyi Kart

İyi bir kart:

- ne olduğunu hemen anlatır
- tek ana bilgi taşır
- tek ana aksiyon sunar
- statusu net gösterir
- ferah padding kullanır
- sakin border/shadow kullanır

## 6.2 Kötü Kart

Kötü kart:

- çok fazla badge taşır
- 3-4 aksiyon sunar
- küçük metinle dolar
- gölge/renk abartır
- dosya statusunu gizler
- tıklanabilir alanı belirsiz yapar

## 6.3 Dosya Kartı Bilgileri

Drive file card içinde ideal bilgiler:

```txt
Dosya adı
Dosya tipi
Kısa metadata: sayfa / boyut / tarih
Status badge
Ana aksiyon: kullan / detay / tekrar dene
```

---

# 7. Durum Sistemleri

Durum göstergeleri kullanıcının güvenini belirler.

## 7.1 File Status

Olası durumlar:

```txt
Hazır
İşleniyor
Taslak
Hata
Metin bulunamadı
Desteklenmiyor
```

## 7.2 Durum Dili

Ready:

```txt
Hazır
Bu kaynak üretim için kullanılabilir.
```

Processing:

```txt
İşleniyor
Kaynak okunuyor. Hazır olduğunda kullanabilirsin.
```

Error:

```txt
İşlenemedi
Dosya işlenirken sorun oluştu.
```

Unsupported:

```txt
Desteklenmiyor
Bu dosya biçimi şu anda desteklenmiyor.
```

Scanned PDF:

```txt
Metin çıkarılamadı
Bu PDF görüntü tabanlı görünüyor. Metin içeren bir PDF deneyebilirsin.
```

Old PPT:

```txt
Eski PPT desteklenmiyor
Lütfen dosyayı PPTX olarak dışa aktar.
```

---

# 8. Drive Tasarım İlkeleri

Drive, SourceBase'in kalbidir.

Kullanıcı Drive ekranında şunu anlamalı:

```txt
Kaynaklarım burada.
Hangileri hazır belli.
Yeni kaynak yüklemek kolay.
Hazır kaynakla üretim başlatabilirim.
```

## 8.1 Drive Header

Header:

- sade
- kısa
- güven veren
- gereksiz pazarlama metni içermeyen

İyi:

```txt
Kaynakların
PDF, PPTX ve DOCX dosyalarını yükleyip çalışma çıktıları üret.
```

## 8.2 Upload CTA

Upload CTA ekranda net görünmeli.

Öneri:

```txt
Kaynak yükle
PDF, PPTX veya DOCX dosyası ekle
```

CTA:

- ana aksiyon olmalı
- erişilebilir olmalı
- bottom nav altında kalmamalı
- empty state'te özellikle güçlü olmalı

## 8.3 Drive Liste

Liste:

- gereksiz yoğun olmamalı
- dosya kartları okunabilir olmalı
- status badge açık olmalı
- failed/processing dosyalar üretime uygun gibi görünmemeli

---

# 9. BaseForce Tasarım İlkeleri

BaseForce, kullanıcıya çıktı üreten alandır.

Kullanıcı burada şunu hissetmeli:

```txt
Hazır kaynağımı seçtim, şimdi çalışma materyali üretebilirim.
```

## 9.1 Üretim Kartları

Kartlar:

- Flashcard Factory
- Soru Fabrikası
- Özet
- Akış Şeması / Algoritma
- Karşılaştırma Tablosu

MVP önceliği:

```txt
Flashcard
Soru
Özet
```

Diğerleri gerekirse “yakında” veya disabled olabilir.

## 9.2 Kaynak Seçimi

Kaynak seçilmeden üretim başlatılmamalı.

Kaynak seçimi:

- görünür
- değiştirilebilir
- statusu belli
- failed/processing kaynaklar engellenmiş olmalı

---

# 10. Generation Loading

Loading ekranı güven vermeli.

İyi loading akışı:

```txt
Kaynağın analiz ediliyor
Flashcard yapısı hazırlanıyor
Sonuç oluşturuluyor
```

Kötü:

```txt
Yapay zeka sihrini yapıyor
Süper zeka kaynaklarını dönüştürüyor
```

Loading state:

- sonsuz spinner hissi vermemeli
- kullanıcı ne beklendiğini anlamalı
- hata olursa anlaşılır mesaj verilmeli
- geri çıkma veya bekleme davranışı net olmalı

---

# 11. Result Ekranı

Result ekranı ürünün değer kanıtıdır.

Kullanıcı sonuç ekranında:

- çıktıyı okumalı
- kopyalayabilmeli
- kaydedebilmeli
- yeniden üretebilmeli
- kaynakla bağlantısını anlayabilmeli

## 11.1 Flashcard

Flashcard:

- soru/cevap ayrımı net
- kartlar ferah
- uzun cevaplar okunabilir
- gereksiz renk yok

## 11.2 Soru

Soru:

- soru kökü net
- seçenekler düzenli
- doğru cevap ve açıklama ayrımı belirgin

## 11.3 Özet

Özet:

- başlıklar net
- maddeler okunabilir
- uzun paragraflar bölünmüş
- klinik önem vurgusu sade

---

# 12. Empty State

Empty state boşluk değil, yönlendirmedir.

Drive empty:

```txt
Henüz kaynak yok
PDF, PPTX veya DOCX yükleyerek çalışma materyali üretmeye başlayabilirsin.
[İlk kaynağını yükle]
```

BaseForce empty:

```txt
Önce bir kaynak seç
Flashcard veya soru üretmek için hazır bir kaynak seçmelisin.
[Kaynak seç]
```

Result empty:

```txt
Henüz sonuç yok
Bir üretim başlattığında sonuç burada görünecek.
```

---

# 13. Error State

Error state:

- problemi açıklar
- kullanıcıya sonraki adımı verir
- teknik hata dump etmez
- panik yaratmaz

Örnek:

```txt
Dosya işlenemedi
Bu dosyadan okunabilir metin çıkarılamadı. Farklı bir PDF veya DOCX deneyebilirsin.
```

CTA:

```txt
Tekrar dene
Farklı dosya yükle
Detaya bak
```

---

# 14. Bottom Navigation

Bottom navigation:

- safe area üzerinde
- içerik kapatmayan
- kısa etiketli
- aktif state'i net
- fazla kalabalık olmayan yapıdadır

Önerilen bölümler:

```txt
Drive
BaseForce
SourceLab
AI
Profil
```

MVP için:

```txt
Drive
BaseForce
Profil
```

---

# 15. iOS Native Hissi

Flutter veya Swift fark etmez; SourceBase iPhone'da native hissettirmelidir.

Bunun için:

- doğal scroll
- net navigation
- sayfa geçişlerinde tutarlılık
- çok küçük dokunma alanlarından kaçınma
- safe area doğruluğu
- modal/sheet davranışlarında iOS ergonomisi
- bottom CTA'nın başparmak bölgesinde olması

---

# 16. Yapay Zeka Kokusu Yasağı

Aşağıdakilerden kaçın:

- robot kafası ikonları
- neon mor-mavi grid
- “AI magic”
- “sihirli”
- “geleceğin zekası”
- yapay zeka maskotu
- aşırı parlak gradient
- stok görsel gibi duran AI sahneleri

SourceBase akıllı görünmeli ama AI reklamı gibi görünmemeli.

---

# 17. Kabul Kriterleri

Bir ekran kabul edilir:

- ana aksiyon netse
- ekran sıkışık değilse
- statuslar anlaşılırsa
- hata/empty/loading state profesyonelse
- iPhone'da taşma yoksa
- bottom nav içerik kapatmıyorsa
- metinler sade ise
- kartlar premium ise
- kullanıcı ne yapacağını anlıyorsa
- tıp öğrencisine güven veriyorsa

Bir ekran reddedilir:

- tek ekrana zorla sıkıştırılmışsa
- CTA belirsizse
- dosya statusu anlaşılmıyorsa
- AI/neon kokuyorsa
- bottom nav içerik kapatıyorsa
- teknik hata doğrudan gösteriliyorsa
- kullanıcı akışı belirsizse

---

# 18. İlk Tasarım Patch Hedefi

İlk patch için en iyi hedef:

```txt
Drive Home
```

Çünkü Drive iyi değilse kullanıcı ürünün değerine ulaşamaz.

Drive Home patch'i şunları hedeflemeli:

- header sadeleştirme
- upload CTA güçlendirme
- file card spacing iyileştirme
- status badge netleştirme
- empty/error/loading state iyileştirme
- bottom safe area kontrolü
- backend logic'e dokunmama

---

# 19. İkinci Patch Hedefi

İkinci patch:

```txt
BaseForce Home
```

Hedef:

- üretim kartları daha net
- kaynak seçimi görünür
- disabled state kaliteli
- Flashcard/Soru/Özet öncelikli
- üretim aksiyonu net
- MC maliyeti varsa okunur

---

# 20. Son Tasarım İlkesi

Süsleme değil, anlaşılabilirlik.

SourceBase'te premium tasarım:

```txt
Az şey söyler.
Doğru şeyi söyler.
Kullanıcıyı bir sonraki adıma taşır.
```
