# TUR 3 CTA GORUNURLUK CHECKLIST - DESIGN RESPONSIVE UX

## Kanit dosyalari
- iPhone 14 canlı ekran: `AGENT_TUR3_iphone14.png`
- Tablet canlı ekran: `AGENT_TUR3_tablet.png`
- Web canlı ekran: `AGENT_TUR3_web.png`

Not: Bu görseller canlı deploy edilmiş sürümden alınmıştır. Yerel patch görsel doğrulaması için bu ortamda Flutter SDK yok; patch sonrası lokal run/screenshot alınamadı.

## iPhone 14 390x844
- Drive ana CTA: Canlı sürümde görünüyor, fakat hero çok yüksek. Patch ile mobil hero sıkılaştırıldı ve CTA full-width orta boy yapıldı.
- Drive alt güvenli alan: Canlı sürümde ders/alt içerik bottom nav ile yarışıyor. Patch ile `SourceBaseBottomNav.contentBottomPadding` nav yüksekliği + safe area + 36px buffer olarak standardize edildi.
- BaseForce “Aç”: Canlı sürümde ilk anlamlı viewportta bottom nav altında kalıyor. Patch ile BaseForce home hero `heroTight` yapıldı, mobil art kaldırıldı, factory kartları sıkılaştırıldı.
- SourceLab “Başlat”: Canlı sürümde ilk anlamlı viewportta bottom nav altında kalıyor. Patch ile SourceLab home hero `tight`, kaynak paneli daha kısa, boş kaynak durumunda birincil CTA `Kaynak Seç`, tool kartları daha kompakt.
- Auth duplicate semantics: Canlı sürümde “Giriş Yap Giriş Yap” görüldü. Patch ile `SBPrimaryButton` ve `SBSecondaryButton` görsel child’ları `ExcludeSemantics` içine alındı.

## Tablet 768x1024
- Nav rail: Canlı sürümde rail görünüyor ve içerik max-width içinde kalıyor.
- Drive CTA/grid: Kullanılabilir; patch mobil odaklı, tablet düzenini koruyor.
- BaseForce/SourceLab kartları: Tablet için grid davranışı korunuyor.

## Web 1440x900
- Nav rail: Canlı sürümde desktop rail doğru görünüyor.
- İçerik genişliği: Max-width içinde kalıyor, kontrolsüz yayılma gözlenmedi.
- Patch etkisi: Bottom nav ve mobil hero değişiklikleri desktop nav rail düzenine dokunmuyor.
