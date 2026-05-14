# MedAsi Card Station Plani

## Amac

MedAsi ekosisteminde Qlinik, Card Station / Flashcard ve ileride gelecek diger uygulamalar tek server ve tek Supabase/Postgres veritabani uzerinde calisacak. Buna ragmen uygulama verileri birbirine karismayacak; her uygulama kendi alaninda kalacak, ortak kullanici, ortak paket/cuzdan ve ortak ogrenme sinyalleri uzerinden kontrollu sekilde haberlesecek.

Bu planin ana hedefi sudur:

- Bugun App Store'a gonderilecek Qlinik surumunu bozmamak.
- Eski Qlinik mobil surumleri aylarca kullanilsa bile server kontratini korumak.
- Card Station'i yeni bir uygulama olarak eklemek.
- Qlinik ve Card Station arasinda akilli veri akisi kurmak.
- Tek database icinde duzenli, guvenli ve buyuyebilir MedAsi mimarisi kurmak.

## Temel Karar

Tek server ve tek database kullanilacak. Ancak tek database icinde uygulamalar dogrudan birbirinin tablolarini kurcalamayacak.

Dogru model:

- `core`: MedAsi ortak cekirdegi.
- `qlinik`: Qlinik'e ait veri ve is kurallari.
- `card_station`: Flashcard/Card Station'a ait veri ve is kurallari.
- `admin`: admin panel, audit log, import ve operasyonel araclar.
- `analytics`: uygulamalar arasi raporlama ve ozet gorunumler.

Ilk asamada fiziksel Postgres schema ayirimina hemen gecmek zorunda degiliz. Mevcut Qlinik canli oldugu icin geriye uyumluluk daha onemli. Yeni tablolar ve endpoint'ler eklenerek ilerlenmeli; mevcut Qlinik tablolarini yeniden adlandirma veya tasima islemi sonraki kontrollu migration fazina birakilmali.

## Bugunku Qlinik Surumu Icin Degismez Kurallar

App Store'a giden bugunku Qlinik surumu server tarafinda su kontratlara guveniyor:

- Supabase Auth endpoint'leri.
- `/functions/v1/qlinik` Edge Function endpoint'i.
- Qlinik action isimleri:
  - `bootstrap_profile`
  - `save_contact`
  - `delete_account`
  - `question_filters`
  - `qlinik_bootstrap`
  - `next_questions`
  - `submit_answer`
  - `reset_question_filter`
  - `spot_fact_feedback`
  - `mistake_review`
  - `mistake_dismiss`
  - `dashboard`
  - `ai_plan`
  - `mentor_chat`
  - `store`
  - `purchase_bundle`
  - `redeem_gift_code`
  - `ask_ai`

Bu kontratlar kirilmayacak. Yeni uygulama eklenirken:

- Mevcut action silinmeyecek.
- Response alanlari kaldirilmayacak.
- Mevcut RPC fonksiyonlari geriye uyumsuz degistirilmeyecek.
- Qlinik'in kullandigi tablo isimleri apar topar degistirilmeyecek.
- Eski mobil surumlerin bekledigi davranis korunacak.

Kural: Yeni ihtiyac varsa yeni endpoint, yeni action, yeni tablo veya yeni kolon eklenir. Eski kontrat kirilmaz.

## Hedef Mimari

### 1. Core Katmani

`core` MedAsi'nin ortak beynidir. Tum uygulamalarin paylastigi fakat tek bir uygulamaya ait olmayan veriler burada tutulur.

Onerilen core varliklari:

- `core.applications`
  - `id`
  - `code`: `qlinik`, `card_station`, `academy`, `case_sim` gibi.
  - `name`
  - `is_active`
  - `created_at`

- `core.user_apps`
  - `user_id`
  - `app_code`
  - `status`: `active`, `disabled`, `trial`, `blocked`
  - `first_seen_at`
  - `last_seen_at`

- `core.profiles`
  - MedAsi ortak profil bilgisi.
  - Ad, soyad, e-posta, telefon, tercih edilen dil, temel ayarlar.
  - Qlinik'e ozel hedef veya sinif seviyesi gibi alanlar uzun vadede app-specific profile'a tasinabilir.

- `core.entitlements`
  - Kullanici hangi uygulamada hangi hakka sahip?
  - Paket, abonelik, kota, premium ozellikler.

- `core.wallet`
  - Ortak coin/kredi bakiyesi.
  - Harcama ve yukleme tum uygulamalarda izlenebilir.

- `core.purchases`
  - App Store, Play Store, promo, manuel satis kayitlari.
  - Hangi urunun hangi uygulama veya tum ekosistem icin gecerli oldugu ayrilir.

- `core.taxonomy`
  - Ortak konu agaci.
  - Ornek: TUS > Dahiliye > Kardiyoloji > Aritmiler.
  - Qlinik soru, Card Station kart ve ileride video/mini ders ayni taxonomy'ye baglanir.

- `core.learning_events`
  - Uygulamalar arasi haberlesmenin ana mekanizmasi.
  - Qlinik, Card Station'a direkt tablo uzerinden emir vermez; ogrenme olayi uretir.

### 2. Qlinik Katmani

Qlinik kendi domain'inde kalir.

Mevcut Qlinik varliklari:

- soru bankasi
- soru teslimati
- cevap denemeleri
- yanlislar
- filtreler
- AI planlar
- mentor
- dashboard
- spot facts

Qlinik, Card Station icin kart olusturmak zorunda degildir. Qlinik sadece su tur sinyalleri uretmelidir:

- kullanici su konuda zayif
- kullanici su soruyu yanlis yapti
- kullanici su konuyu tekrar etmeli
- kullanici su konuda guclendi
- kullanici su AI plani/mentor onerisine sahip

Bu sinyaller `core.learning_events` veya kontrollu bir RPC ile paylasilir.

### 3. Card Station Katmani

Card Station kendi verilerini tutar.

Onerilen tablolar:

- `card_station.decks`
  - kart desteleri
  - kullaniciya ozel veya sistem destesi olabilir

- `card_station.cards`
  - soru/cevap, cloze, klinik ipucu, mini not gibi kart tipleri
  - taxonomy baglantisi
  - kaynak: manuel, AI, Qlinik yanlisi, admin import

- `card_station.card_reviews`
  - spaced repetition tekrar kayitlari
  - kullanici karti ne zaman gordu, nasil cevap verdi

- `card_station.card_schedule`
  - sonraki tekrar tarihi
  - kolaylik katsayisi, interval, tekrar sayisi

- `card_station.card_sources`
  - kartin hangi olaydan uretildigi
  - ornek: Qlinik wrong answer, AI mentor suggestion, admin seed

- `card_station.user_card_settings`
  - gunluk hedef
  - bildirim tercihi
  - zorluk seviyesi

Card Station'in API'si ayri olacak:

- `/functions/v1/card-station`

Olası action'lar:

- `bootstrap`
- `list_decks`
- `next_cards`
- `submit_review`
- `generate_from_weak_topics`
- `save_card`
- `dismiss_card`
- `deck_progress`

## Qlinik ve Card Station Haberlesmesi

### Senaryo 1: Qlinik Yanlisindan Kart Onerme

Akis:

1. Kullanici Qlinik'te soru cozer.
2. `submit_answer` calisir.
3. Cevap yanlissa Qlinik kendi kaydini yazar.
4. Ayrica ortak bir learning event olusturur:
   - `source_app = qlinik`
   - `event_type = wrong_answer`
   - `subject = Kardiyoloji`
   - `topic = Aritmiler`
   - `question_id = ...`
   - `user_id = ...`
5. Card Station bu event'i okuyup kart onerisi uretir.
6. Kullanici isterse karti destesine ekler.

Qlinik, Card Station tablosuna dogrudan yazmak zorunda degildir. Bu daha guvenli ve daha esnektir.

### Senaryo 2: Card Station Tekrar Basarisi Qlinik Mentor'una Yansisin

Akis:

1. Kullanici Card Station'da Aritmiler kartlarini basariyla tekrarlar.
2. Card Station kendi `card_reviews` kaydini yazar.
3. Ortak event olusturur:
   - `source_app = card_station`
   - `event_type = topic_reinforced`
   - `subject = Kardiyoloji`
   - `topic = Aritmiler`
   - `score = high`
4. Qlinik dashboard veya mentor bu sinyali kullanir:
   - "Bu konu tekrar edildi."
   - "Zayif konu listesinde agirligi azalt."
   - "Yeni soru onerilerini buna gore guncelle."

### Senaryo 3: Ortak Paket ve Coin Kullanimi

Akis:

1. Kullanici MedAsi coin satin alir.
2. Coin core wallet'a yazilir.
3. Qlinik AI soru analizi coin harcayabilir.
4. Card Station AI kart uretimi coin harcayabilir.
5. Her uygulama harcamayi kendi ozelligi icin yapar ama bakiye ortaktir.

Burada kritik nokta: wallet core'a aittir, Qlinik veya Card Station'a ait degildir.

## RLS ve Guvenlik Modeli

Tum uygulamalarda temel kural:

- Mobil/web client direkt hassas tablolara yazmaz.
- Kritik islemler Edge Function veya RPC uzerinden yapilir.
- Service role sadece server tarafinda kullanilir.
- Kullanici token'i ile gelen istek once auth edilir.
- Her action kendi yetki ve rate limit kontrolunden gecer.

Onerilen erisim modeli:

- `anon`: minimum erisim.
- `authenticated`: sadece kendi public/okunabilir verisi.
- `service_role`: Edge Function ve admin operasyonlari.
- Admin islemleri: Supabase Auth `app_metadata.is_admin` veya ayri admin yetki modeli.

Card Station icin de Qlinik'teki model tekrar edilmeli:

- action router
- auth middleware
- rate limit
- payload validation
- service role ile kontrollu DB islemi
- response kontratini sabit tutma

## Migration Stratejisi

Bu gece veya ilk release icin buyuk DB refactor yapilmayacak.

### Faz 0: Qlinik'i Korumak

Yapilacaklar:

- Mevcut Qlinik endpoint'i korunur.
- Mevcut migrations geriye uyumlu kalir.
- Yeni app icin Qlinik tablolari tasinmaz.
- Eski App Store surumunun calismasi garanti edilir.

Yapilmayacaklar:

- `public.profiles` adini degistirmek.
- `question_attempts` tasimak.
- `/functions/v1/qlinik` kontratini bozmak.
- Store/purchase yapisini bir gecede tamamen yeniden yazmak.

### Faz 1: Core Kavramlari Eklemek

Yeni tablolar eklenir, eski tablolar bozulmaz.

Olası eklemeler:

- `applications`
- `user_apps`
- `learning_events`
- `taxonomy` veya mevcut taxonomy icin uyum tablolari
- entitlement/cuzdan ayrimi gerekiyorsa geriye uyumlu kolonlar

Bu fazda Qlinik hala eski sekilde calismaya devam eder.

### Faz 2: Card Station MVP

Card Station ayri endpoint ve ayri tablo seti ile gelir.

Minimum MVP:

- kullanici girisi ayni Supabase Auth ile
- deck listesi
- kart listeleme
- kart tekrar etme
- spaced repetition temel algoritmasi
- Qlinik zayif konularindan kart onerisi

Card Station bu fazda Qlinik tablolarina direkt yazmaz. Sadece event/summary/RPC uzerinden bilgi alir.

### Faz 3: Uygulamalar Arasi Ogrenme Katmani

Bu fazda ekosistem guclenir.

Eklenebilecekler:

- ortak learning score
- konu bazli gucluluk/zayiflik modeli
- Qlinik dashboard'da Card Station tekrar etkisi
- Card Station'da Qlinik yanlislarindan otomatik kart onerisi
- mentor'un tum MedAsi calisma gecmisini yorumlamasi

### Faz 4: Temiz Schema Ayrimi

Canli kullanici sayisi ve veri modeli oturduktan sonra yapilir.

Hedef:

- `public` minimumda kalir.
- `core`, `qlinik`, `card_station`, `admin`, `analytics` ayrimi netlesir.
- Eski endpoint'ler view/RPC ile geriye uyumlu tutulur.

Bu faz dikkatli migration, backup ve rollback plani ister.

## Card Station MVP Detayi

### Ana Ekran

Kullanici Card Station'i actiginda sunlari gormeli:

- Bugunku tekrar sayisi.
- Yeni kart sayisi.
- Qlinik'ten gelen oneriler.
- Zayif konulara gore calisma desteleri.
- Gunluk seri/streak.

### Kart Tipleri

Ilk surum icin yeterli kart tipleri:

- Basic:
  - on yuz: soru
  - arka yuz: cevap

- Cloze:
  - cumle icinde bosluk doldurma

- Clinical Pearl:
  - kisa, ezberletici klinik ipucu

- Mistake Card:
  - Qlinik'te yanlis yapilan sorudan turetilen kart

### Spaced Repetition

Ilk surumde basit bir algoritma yeterli:

- Again
- Hard
- Good
- Easy

Her cevap sonraki tekrar tarihini belirler. Daha sonra FSRS veya SM-2 gibi daha gelismis algoritmaya gecilebilir. Ilk release icin algoritma basit, veri modeli ise gelismeye acik tutulmali.

### Qlinik Baglantisi

Card Station'da "Qlinik'ten Onerilenler" bolumu olabilir.

Kaynaklar:

- son yanlis cevaplar
- zayif konular
- mentor onerileri
- sik unutulan spot fact'ler

Card Station bu kaynaklardan kart uretirken kullaniciya kontrol vermeli:

- karta ekle
- daha sonra
- bunu gosterme
- bu konudan daha fazla oner

## Geriye Uyumluluk Kurallari

Bu kurallar kesin:

- Eski Qlinik app surumu yeni server ile calismaya devam etmeli.
- Yeni kolon eklemek serbest, kolon silmek riskli.
- Yeni response alani eklemek serbest, alan kaldirmak riskli.
- Yeni action eklemek serbest, action silmek riskli.
- Yeni tablo eklemek serbest, tablo tasimak riskli.
- Mevcut RPC imzasini degistirmek riskli; gerekiyorsa yeni RPC eklenmeli.

Ornek:

Yanlis:

- `submit_answer_compact(p_user_id, p_question_id, p_selected_index)` fonksiyonunu kiracak sekilde degistirmek.

Dogru:

- `submit_answer_compact_v2(...)` eklemek.
- Qlinik router'da yeni app surumu icin v2 kullanmak.
- Eski app surumleri v1 ile devam etmek.

## Deployment Kurallari

MedAsi standing orders geregi:

```text
Local Code -> git push origin main -> Docker Build -> Coolify Deploy
```

Bu zincir bozulmayacak.

DB veya Edge Function degisikligi varsa:

- Yeni migration dosyasi eklenecek.
- Eski migration duzenlenmeyecek.
- Commit atilacak.
- `git push origin main` yapilacak.
- Coolify build tetiklenecek.
- Edge Function deployment durumu ayrica kontrol edilecek.
- Canli smoke test yapilacak.

## Smoke Test Listesi

Qlinik icin:

- app aciliyor mu?
- kullanici giris yapabiliyor mu?
- dashboard geliyor mu?
- soru cekiliyor mu?
- cevap gonderiliyor mu?
- yanlis cevap dashboard'a dusuyor mu?
- store/paket ekrani calisiyor mu?
- AI action'lari quota ile calisiyor mu?
- auth olmayan istekler 401 donuyor mu?

Card Station icin:

- ayni Supabase kullanicisi ile giris.
- deck listesi.
- kart cekme.
- review gonderme.
- tekrar tarihi hesaplama.
- Qlinik zayif konu onerisi.
- kullanici sadece kendi kart/review verisini gorebiliyor mu?

Ekosistem icin:

- ayni kullanici iki uygulamada da ayni `user_id` ile gorunuyor mu?
- core wallet/entitlement dogru okunuyor mu?
- Qlinik ve Card Station olaylari birbirine karismadan `learning_events` uzerinden gorunuyor mu?

## Riskler

### Risk 1: Qlinik'i Kirarak Flashcard Eklemek

En buyuk risk budur. Cozum: Flashcard yeni endpoint ve yeni tablolarla gelir.

### Risk 2: Ortak Profilin Sisirilmesi

Her uygulama kendi ayarini `profiles` tablosuna eklerse profil tablosu cop olur. Cozum: ortak profil core'da, app-specific ayarlar uygulama alaninda tutulur.

### Risk 3: Paket ve Cuzdanin Uygulama Icine Gomulmesi

Qlinik icin yapilan wallet ileride Card Station ile ortak kullanilmak istenirse karmasa cikar. Cozum: wallet/entitlement core kavrami olarak ele alinmali.

### Risk 4: Direkt Tablo Bagimliligi

Card Station, Qlinik tablolarini direkt okursa ileride Qlinik refactor edilemez. Cozum: event, view veya RPC kontrati.

### Risk 5: Mobil Surumlerin Uzun Yasamasi

App Store'a giden surum uzun sure kullanilabilir. Cozum: API versioning ve geriye uyumlu server davranisi.

## Onerilen Zaman Plani

### Bu Gece

- Qlinik release korunur.
- Ekosistem refactor yapilmaz.
- Sadece release icin gerekli test ve deployment yapilir.

### Sonraki 1-2 Gun

- Core taslak migration plani hazirlanir.
- `learning_events` modeli netlestirilir.
- Card Station MVP veri modeli cizilir.
- Qlinik'ten hangi sinyallerin paylasilacagi belirlenir.

### Sonraki Hafta

- Card Station Edge Function iskeleti.
- Card Station temel tablolar.
- Deck ve review akisi.
- Qlinik zayif konu sinyallerinden kart onerisi.

### Sonraki Faz

- Ortak wallet/entitlement modeli temizlenir.
- Admin panelde uygulama secici ve cross-app kullanici gorunumu eklenir.
- Analytics katmani kurulur.

## Nihai Mimari Prensip

MedAsi tek bir ekosistem olacak; ama her uygulama kendi domain'ini koruyacak.

En saglikli cumle:

```text
Ayni kullanici, ayni database, ayni server;
ama ayri uygulama alanlari, kontrollu ortak cekirdek ve event tabanli haberlesme.
```

Bu modelle Qlinik bugunku haliyle canli kalir, Card Station yarin eklenir, sonraki uygulamalar da sistemi dagitmadan ayni omurgaya baglanir.
