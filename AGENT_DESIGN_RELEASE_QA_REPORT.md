# AJAN 5 — DESIGN / RESPONSIVE / RELEASE QA RAPORU

## 1. Branch ve Repo Doğrulaması

- Repo kökü: `/Volumes/driveand/sourcebase-agents/sb-design-release-qa`
- Branch: `agent/design-release-qa`
- Status: rapor öncesi çalışma ağacında yalnızca önceki ara QA dokümantasyon dosyası untracked görünüyordu; production kod değişikliği yoktu.

## 2. İncelediğim Alanlar

- Tasarım sistemi: tema, marka widget'ı, buton/spacing yaklaşımı ve mevcut premium klinik/akademik çizgi.
- Responsive yapı: `ResponsiveLayout`, workspace scroll davranışı ve mobil/tablet/web sınırları.
- Bottom nav/safe area: `SourceBaseBottomNav` helper'ları, scroll padding ve içerik overlap riski.
- SF Pro font riski: `SF Pro Display` kullanımının asset tanımı olmadan zorlanması.
- CSP/nginx riski: `nginx.conf` güvenlik header'ları ve CSP eksikliği.
- Maestro dosyaları: Agent 1-4 smoke flow dosyaları ve appId/runtime durumu.
- Flutter/Deno test durumu: Flutter komutları, Deno check/test komutları ve `git diff --check`.
- Release blocker'lar: Flutter doğrulaması, payment action, CSP, Maestro doğrulaması.
- Merge sırası: Agent 1-5 mantıksal entegrasyon sırası.

## 3. Genel Durum

SourceBase branch'i release'e yaklaşmış görünüyor; Drive ingestion, BaseForce, SourceLab/Central AI ve Profile/Store alanları için ajan raporları mevcut. Deno tarafındaki SourceBase ve ai-services check'leri geçiyor, extraction/file-type testleri başarılı. Buna rağmen Flutter SDK bu ortamda bulunmadığı için frontend analyze/test/build doğrulaması yapılamadı. CSP eksikliği, `purchase_medasicoin` backend action eksikliği ve Maestro doğrulama eksikleri nedeniyle branch şu an merge-safe/release-safe kabul edilmemeli.

## 4. Release Blocker'lar

### Critical

- `flutter analyze`, `flutter test` ve `flutter build web --release` bu ortamda çalıştırılamadı; Flutter komutu yok.
- Frontend release için exact candidate commit üzerinde Flutter doğrulaması alınmadan merge/deploy yapılmamalı.

### High

- Store UI `purchase_medasicoin` çağırıyor, ancak `supabase/functions/sourcebase/index.ts` içinde bu action yok. UI fake success göstermiyor, fakat ücretli satın alma fonksiyonel değildir.
- `nginx.conf` içinde `Content-Security-Policy` yok. Public web release öncesi Flutter uyumlu CSP tanımlanmalı veya release owner tarafından açıkça defer edilmeli.
- Maestro flow'ları Java Runtime eksik olduğu için lokal doğrulanamadı.

### Medium

- `maestro/flows/drive_ingestion_agent1.yaml` içinde `appId: com.medasi.sourcebase` kullanılıyor; Android tarafındaki gerçek appId `tr.com.medasi.sourcebase`.
- SF Pro font referansı asset tanımı olmadan kullanılıyor; platformlar arası font tutarlılığı garanti değil.
- iPhone/tablet/web görsel QA screenshot'ları mevcut candidate build üzerinde yenilenmeli.

### Low

- Maestro flow'ları smoke test niteliğinde; responsive screenshot QA'nın yerine geçmez.
- Payment CTA kapalı/defer edilmiş release senaryosu seçilirse kullanıcı metinleri ayrıca ürün/release owner tarafından onaylanmalı.

## 5. Tasarım Blocker'ları

- `SourceBaseTheme` ve `SourceBaseBrand` doğrudan `SF Pro Display` kullanıyor; `pubspec.yaml` içinde font asset tanımı yok.
- Güvenli font önerisi: açık SF Pro zorlamasını kaldırıp platform font fallback'e dönmek veya lisanslı/bundle edilen bir fontu asset olarak tanımlamak.
- Apple SF Pro dosyaları lisans teyidi olmadan repoya eklenmemeli.
- Mevcut premium, klinik, akademik ve sakin tasarım hattı korunmuş görünüyor; generic SaaS/glow/robot klişesi yönünde yeni risk görülmedi.

## 6. Responsive Blocker'ları

- Bottom nav tarafında safe-area helper ve ek scroll padding var; statik incelemede doğrudan overlap kanıtı görülmedi.
- Yine de Flutter build alınamadığı için gerçek mobil/tablet/web viewport görsel doğrulaması yapılamadı.
- Maestro flow'ları responsive kırılım testinin yerine geçmez; iPhone 14, tablet ve web screenshot QA yeniden alınmalı.
- CTA görünürlüğü, bottom nav üstü son içerik ve safe-area davranışı canlı veya lokal build üzerinde tekrar kontrol edilmeli.

## 7. Güvenlik Blocker'ları

- `nginx.conf` içinde CSP eksik.
- Payment action eksikliği nedeniyle store release'i başarılı satın alma ima etmemeli.
- CORS fallback `https://sourcebase.medasi.com.tr` ile sınırlı görünüyor; GCS CORS production ve localhost dev origin'lerini içeriyor.
- Qlinik'e özel dosya yolu bulunmadı.
- `.env`, service account JSON, private key, token veya secret runtime dosyası açılmadı/yazdırılmadı.

## 8. Test ve Build Durumu

Çalıştırılan ve geçen komutlar:

- `pwd`
- `git rev-parse --show-toplevel`
- `git branch --show-current`
- `git status --short`
- `deno check supabase/functions/sourcebase/index.ts`
- `deno check supabase/functions/ai-services/index.ts`
- `deno test --no-check --allow-all supabase/functions/sourcebase/services/file-types.test.ts supabase/functions/sourcebase/services/extraction.test.ts` → 10/10 geçti.
- `git diff --check`

Çalıştırılamayan komutlar:

- `flutter analyze` → `flutter` komutu yok.
- `flutter test` → `flutter` komutu yok.
- `flutter build web --release` → `flutter` komutu yok.
- `maestro --version` → Java Runtime eksik.

## 9. Her Ajan İçin Beklenen Çıktı

### Backend

- SourceBase Edge Function action contract'larının korunması.
- AI job creation/process/polling akışının deterministik kalması.
- Provider/backend hata mesajlarının UI'a raw secret, stack veya provider payload olarak sızmaması.
- Deno check/test komutlarının exact candidate commit üzerinde geçmesi.

### Drive

- Drive ingestion/extraction hardening.
- PDF/DOCX/PPTX destek davranışı ve unsupported/legacy format mesajlarının net olması.
- 0 KB, failed, processing, uploading ve draft kaynakların generation için seçilememesi.
- Drive upload ve extraction testlerinin korunması.

### BaseForce

- `create_generation_job -> process_generation_job -> get_job_status/get_generated_content` sırasının korunması.
- Flashcard, quiz, summary, algorithm ve comparison modlarında kaynak gating ve polling/result görünürlüğünün korunması.
- Fake progress/success göstermeme.
- MC/cost bilgisinin gerçek backend sonucu olmadan başarılı işlem gibi sunulmaması.

### SourceLab/Central AI

- SourceLab modlarında gerçek Drive kaynak context'i, owner kontrolü ve polling sonucunun korunması.
- Central AI için seçili hazır Drive dosya id'lerinin backend context'e taşınması.
- Provider hatalarının kullanıcı dostu ve güvenli metinlere normalize edilmesi.
- Podcast için gerçek ses entegrasyonu yoksa bunun açıkça metinsel script olarak konumlanması.

## 10. Merge Sırası

Önerilen mantıksal merge sırası:

1. Agent 1 Drive ingestion.
2. Agent 2 BaseForce.
3. Agent 3 SourceLab/Central AI.
4. Agent 4 Profile/Store state.
5. Agent 5 Design/Responsive/Release QA.

Merge guard: exact candidate commit üzerinde Flutter analyze/test/build geçmeden ve release blocker'lar çözülmeden protected branch'e merge yapılmamalı.

## 11. Deploy Öncesi Şartlar

- Web deploy ayrı ele alınmalı: Flutter analyze, test ve `flutter build web --release` geçmeden web deploy yapılmamalı.
- Edge Function deploy ayrı ele alınmalı: Deno check/test exact commit üzerinde geçmeli, required secrets target ortamda mevcut olmalı, secret değerleri loglara yazdırılmamalı.
- DB migration deploy ayrı ele alınmalı: mevcut görevde migration değiştirilmedi; migration uygulama kararı release owner ve backend/DB review ile verilmelidir.
- Frontend deploy, Edge Function deploy ve DB migration aynı rollback kapsamına sokulmamalı.
- CSP policy eksikliği çözülmeli veya açık release waiver ile defer edilmeli.
- `purchase_medasicoin` için backend action/provider uygulanmalı ya da paid purchase CTA release için kapatılmalı/gizlenmeli.
- Maestro appId uyumsuzluğu düzeltilmeli ve Java + device/simulator ortamında flow'lar tekrar çalıştırılmalı.
- Telefon/tablet/web görsel QA screenshot'ları candidate build üzerinden yenilenmeli.

## 12. Ana Terminalde Birleştirme İçin Talimat

Ana terminalde şu branch/rapor yüzeyleri toplanmalı:

- Agent 1 Drive ingestion: `agent-1-drive-ingestion`, rapor `docs/agent-1-drive-ingestion-report.md`.
- Agent 2 BaseForce: `agent-2-baseforce`, rapor `docs/agent-2-baseforce-report.md`.
- Agent 3 SourceLab/Central AI: `agent-3-sourcelab-ai`, rapor `docs/agent-3-sourcelab-ai-report.md`.
- Agent 4 Profile/Store state: `agent-4-profile-store-state`, rapor `docs/agent-4-profile-store-state-report.md`.
- Agent 5 Integration/Design QA: `agent/design-release-qa` ve mevcut Agent 5 raporları.

Ana terminal merge öncesi:

- Her branch için `git status --short`, `git log --oneline -5`, `git diff --stat` kontrol edilmeli.
- Auth, Qlinik, secrets/env ve migration diff'leri ayrıca filtrelenmeli.
- Flutter analyze/test/build ve Deno check/test exact merge candidate üzerinde tekrar çalıştırılmalı.
- Maestro flow'ları Java + simulator/device olan ortamda tekrar denenmeli.

## 13. Merge Kararı

- Şu an merge güvenli mi? Hayır.
- Güvenli olması için Flutter analyze/test/build geçmeli, CSP açığı çözülmeli veya açıkça defer edilmeli, `purchase_medasicoin` backend action/provider tamamlanmalı veya paid purchase CTA release için kapatılmalı, Maestro appId/runtime doğrulaması yapılmalı, telefon/tablet/web görsel QA yenilenmeli ve secret/env/Qlinik diff kontrolü exact candidate üzerinde tekrar geçmelidir.
