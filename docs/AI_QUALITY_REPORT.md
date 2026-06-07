# SourceBase AI Üretim Kalite Raporu

**Tarih:** 2026-06-07
**Ortam:** Canlı backend (self-hosted Supabase, `46.225.100.139`), edge fonksiyonu `sourcebase`
**Test kullanıcısı:** `ai-qa-1780828106@sourcebase.test` (`50ba20c8-7c25-499c-aa2c-8061dcc62a3d`)
**Kaynak:** Kalp yetmezliği tıbbi metni (Türkçe, ~1.1 KB ham / 2225 karakter çıkarılmış)
**Model:** Tüm metin türleri `gpt-5.4` (OpenAI), infografik `gpt-image-1`
**Kalite seviyesi:** `standard`, `count=5`

## Test metodolojisi (uçtan uca, gerçek persistans)

1. `drive_bootstrap` → kurs/bölüm yoktu, `create_course` + `create_section` ile oluşturuldu.
2. **Önemli kısıt:** Backend yalnızca PDF/DOCX/PPTX kabul ediyor; `.txt`/`text/plain` reddediliyor (`FILE_TYPE_UNSUPPORTED`). Ayrıca üretimin **DB'ye kaydı için gerçek bir `source_file_id` zorunlu** (`SOURCE_FILE_REQUIRED_FOR_OUTPUT`).
3. Bu yüzden kaynak metin, **gerçek metin katmanı içeren bir PDF** (Tj operatörlü, sıkıştırılmamış içerik akışı) olarak elle üretildi, S3'e (`storage.medasi.com.tr`) `curl` ile PUT edildi (HTTP 200), `complete_upload` ile `drive_files` satırı oluşturuldu.
4. `process_file_extraction` doğrulandı: textLength=2225, pageCount=1, tokenEstimate=557. → `fileId=1fb4e4eb-e779-452a-9be8-32f3ad61c6b6`.
5. Her tür için: `create_generation_job` → `process_generation_job` (senkron) → `get_generated_content` + DB sorgusu.

> Not: `curl` (UA filtresi) zorunlu — `python urllib` Cloudflare 1010 ile bloklanıyor.

## Sonuç Tablosu

| Tür | Durum | Süre | Model | Kalite | Sorunlar |
|-----|-------|------|-------|--------|----------|
| flashcard | ✅ completed | 7.6s | gpt-5.4 | ✅ | 5/5 kart, front+back+explanation dolu, kaynağa sadık |
| quiz | ✅ completed | 17.2s | gpt-5.4 | ✅ | 5 soru, her birinde 5 şık, **correctIndex 0–4 dağılımlı**, açıklamalar dolu |
| summary | ❌ failed (500) | 26.4s | gpt-5.4 | ❌ | `INVALID_AI_OUTPUT` — JSON parse edilemiyor (muhtemel truncation) |
| exam_morning_summary | ✅ completed | 22.3s | gpt-5.4 | ✅ | must_know(11), red_flags(5), mini_table, self_check, TUS ipuçları — çok zengin |
| algorithm | ⚠️ completed | 22.3s | gpt-5.4 | ⚠️ | **Dejenere** — fallback tetiklenmiş, adımlar ham kaynak metni ("## Kaynak 1...") |
| comparison | ✅ completed | 14.6s | gpt-5.4 | ✅ | HFrEF/HFpEF tablosu, 8 satır, red_flags + distinguishing_tips dolu |
| clinical_scenario | ✅ completed | 20.6s | gpt-5.4 | ✅ | Olgu + ayırıcı tanı sorusu + kırmızı bayraklar + karar noktası + öğretim noktaları |
| learning_plan | ❌ failed (500) | 30.3s | gpt-5.4 | ❌ | `INVALID_AI_OUTPUT` — JSON parse edilemiyor (muhtemel truncation) |
| mind_map | ✅ completed | 12.8s | gpt-5.4 | ✅ | Merkez konu + 8 dal + children + critical_connections, 3 seviye |
| infographic | ✅ completed | 30.8s | gpt-image-1 | ✅ | **Gerçek PNG** (2.5 MB dataUrl + S3 storageUrl), spec bölümleri dolu |
| podcast | ⚠️ completed | 37.7s | gpt-5.4 | ⚠️ | Transkript (12 segment, doğal Türkçe) var ama **audio_url YOK** |

**Özet:** 11 türden **7 tam başarılı** (flashcard, quiz, exam_morning_summary, comparison, clinical_scenario, mind_map, infographic), **2 kısmi/dejenere** (algorithm, podcast), **2 tamamen bozuk** (summary, learning_plan).

## Broken / Needs Fix (kök neden hipotezleri)

### ❌ 1. `summary` ve `learning_plan` — `INVALID_AI_OUTPUT` (en kritik)
- Her iki tür de **iki bağımsız çalıştırmada da** (sourceText ve fileId yolları) aynı şekilde 500 verdi → flaky değil, **deterministik**.
- AI çağrısı tamamlanıyor (26–30s harcanıyor) ama `parseModelJson` (`services/schema-validator.ts`) JSON.parse'ta düşüyor. Bu parser yalnızca trailing-comma ve akıllı-tırnak tamiri yapıyor; **şema-toleranslı bir validator veya fallback yok**.
- **Kök neden hipotezi: çıktı truncation.** `defaultMaxTokens` (`actions/ai-generation.ts`): kısa kaynakta `summary` ve `learning_plan` için **özel token tavanı tanımlı değil** (`return undefined`), oysa benzer ve başarılı olan `exam_morning_summary`/`clinical_scenario` 4096 token alıyor. Düşük/tanımsız bütçe ile zengin JSON ortada kesiliyor → kapanmamış JSON → parse hatası.
- Bu iki tür, `algorithm` ve `infografik`teki gibi toleranslı bir geri-dönüş yoluna sahip olmadığından kullanıcıya doğrudan 500 dönüyor.

### ⚠️ 2. `algorithm` — dejenere çıktı (sessiz başarısızlık)
- HTTP 200 ama içerik çöp: `notes` alanı *"AI çıktısı beklenen JSON biçiminden saparsa kaynak metne dayalı güvenli akış üretildi"* diyor; `steps[].title` = `"## Kaynak 1 Kalp yetmezligi, kalbin vucudun..."` (ham kaynak metin parçaları).
- Yani algoritma üretiminde de model JSON'u parse edilemedi, **ama burada bir fallback** ham metni adımlara bölerek "başarılı" gösteriyor. Tıp öğrencisi için kullanılamaz: gerçek bir klinik karar akışı (tanı→sınıflama→tedavi basamakları) yok.
- summary/learning_plan ile **aynı kök neden** (model JSON'u/parse) — sadece davranış farkı: biri 500, diğeri sahte 200.

### ⚠️ 3. `podcast` — ses üretilmiyor
- Çıktıda yalnızca `title` + `duration` + `segments[12]` (doğal, akıcı Türkçe transkript) var. `audioUrl`/`audio_url`/`audio` alanı **yok**.
- Beklenen TTS adımı (tts-1) çalışmıyor veya hiç bağlanmamış. Kullanıcı "podcast" bekleyip yalnızca okunacak metin alıyor.

## Çalışan ve gerçekten kaliteli olanlar (med-student gözüyle)
- **quiz**: Sınav kalitesinde. 5 şık, doğru cevap indeksi 0–4 arasında düzgün dağılmış (hep 0 değil), her soruda açıklama. (Şık-bazı rationale yok ama tek açıklama yeterli.)
- **exam_morning_summary**: En zengin çıktı; must_know, red_flags, mini tablo, self-check, TUS ipuçları, sık karıştırılanlar. Kaynağa sadık (ör. "diüretik sağkalımı değiştirmez" tuzağı doğru işaretlenmiş).
- **clinical_scenario**: Tam olgu kurgusu + ayırıcı tanı + kırmızı bayraklar + karar noktası + öğretim noktaları.
- **comparison / mind_map / flashcard**: Yapısal olarak eksiksiz, kaynak-dayanaklı, halüsinasyon yok.
- **infographic**: Gerçek PNG görsel üretiliyor (gpt-image-1, S3'e kaydediliyor), spec bölümleri tutarlı.

## Öncelikli Öneriler

1. **(P0) summary + learning_plan'i düzelt.** `defaultMaxTokens`'a bu iki tür için kısa kaynakta da net token tavanı ver (en az `exam_morning_summary` gibi 4096). Ek olarak `parseModelJson`'a kapanmamış JSON için "auto-close" tamiri ekle (eksik `}`/`]` tamamlama).
2. **(P0) algorithm fallback'ini onar.** Sessizce ham metni adıma çevirmek yerine ya gerçek bir tekrar/retry ya da en azından `exam_morning_summary` tarzı yapısal bir çıktı üret; mevcut dejenere "## Kaynak 1" çıktısı kullanıcıya gitmemeli.
3. **(P1) podcast TTS adımını bağla/etkinleştir.** En azından `audio_url` yoksa cevap şemasında "transcript_only" bayrağı dön; sessizce eksik ses kullanıcıyı yanıltıyor.
4. **(P1) Tüm metin türleri için ortak şema-toleranslı validator.** Her tür kendi `parseJSON`'unu çağırıyor; infografikteki gibi alan-eşleyen toleranslı bir katman (alternatif anahtar adları, eksik alan toparlama) tüm türlere uygulanırsa 500'ler düşer.
5. **(P2) İstemci `extractedText`'i kullanılmıyor.** `complete_upload` `metadata.extractedText` kaydediyor ama `extractTextFromDriveFile` her zaman dosyayı yeniden indirip yeniden çıkarıyor. Metin katmanı olmayan/taranmış PDF'lerde istemci metni boşa gidiyor (`FILE_SCANNED_PDF_OCR_REQUIRED`). İstemci metni varsa onu tercih etmek hem hız hem dayanıklılık kazandırır.

## Ham kanıt (özet)
- Çalıştırma logları + tam çıktılar: sunucuda `/tmp/results.json` (yerel kopya `/tmp/results_local.json`).
- DB doğrulaması: `sourcebase.generated_jobs` — son 11 işten 9'u `completed`, summary & learning_plan `failed` / `error_message='AI çıktısı işlenemedi.'`, tümü `model=gpt-5.4`.
