# SourceBase Üretim Kontrol Listesi

**Tarih:** 17 Mayıs 2026  
**Durum:** ✅ HAZIR

---

## Deploy Öncesi Kontrol

- [x] Flutter analyze temiz (No issues found)
- [x] Flutter test 5/5 geçti
- [x] Flutter build web başarılı
- [x] Dockerfile doğru yapılandırılmış
- [x] nginx.conf güvenlik başlıkları eklendi
- [x] .env.example tam ve güncel
- [x] Hardcoded secret'lar temizlendi (deploy.py, check_deployment.py)
- [x] AppleDouble (`._*`) dosyaları temizlendi
- [ ] Supabase migration'lar uygulandı (20260517 dosyaları)
- [ ] Edge Function deploy edildi
- [ ] Edge Function secret'ları ayarlandı

## Veritabanı Kontrol

- [x] sourcebase şeması mevcut
- [x] RLS politikaları tüm tablolarda aktif
- [x] Index'ler oluşturulmuş
- [x] Trigger'lar (updated_at) çalışıyor
- [ ] 20260517_grant_sourcebase_rest_access.sql uygulandı
- [ ] 20260517_create_sourcebase_storage_roots.sql uygulandı
- [ ] generated_jobs için RLS politikaları kontrol edildi

## Backend (Edge Function) Kontrol

- [x] sourcebase Edge Function kodu tam
- [x] Auth middleware (JWT doğrulama)
- [x] Drive actions (bootstrap, upload, course, section, output)
- [x] AI generation actions (extraction, job, status, content, chat)
- [x] CORS yapılandırması
- [x] GCS signed URL oluşturma
- [ ] Vertex AI service account JSON'ı env'de
- [ ] GCS service account JSON'ı env'de
- [ ] Rate limiting uygulanmış (opsiyonel)

## Frontend/Mobil Kontrol

- [x] Auth ekranları (login, register, forgot password)
- [x] Drive workspace (home, course, section, file detail)
- [x] Bottom navigation (mobil)
- [x] Nav rail (tablet/desktop)
- [x] Hata durumu gösterimi (_ErrorState)
- [x] Responsive layout (mobile/tablet/desktop)
- [ ] Sosyal auth butonları (Google/Apple) - UI'da yok
- [ ] Dosya yükleme progress göstergesi
- [ ] Offline durum bildirimi

## Ödeme Kontrol

- [x] products tablosu
- [x] purchases tablosu
- [x] entitlements tablosu
- [ ] Stripe entegrasyonu
- [ ] Webhook handler
- [ ] Satın alma sonrası entitlement oluşturma

## Güvenlik Kontrol

- [x] Service role key Flutter/browser kodunda yok
- [x] .env gitignored
- [x] .env.example sadece placeholder
- [x] Hardcoded API key'ler temizlendi
- [x] nginx güvenlik başlıkları (X-Frame-Options, X-Content-Type-Options, vb.)
- [x] RLS tüm tablolarda aktif
- [x] CORS sadece sourcebase.medasi.com.tr'e izin veriyor
- [ ] GCS bucket CORS yapılandırması
- [ ] Edge Function rate limiting

## Geri Alma (Rollback) Kontrol

- [ ] Veritabanı backup'ı alındı
- [ ] Önceki Edge Function versiyonu saklandı
- [ ] Önceki Docker image'ı saklandı
- [ ] Coolify'da önceki deployment'a dönüş test edildi
