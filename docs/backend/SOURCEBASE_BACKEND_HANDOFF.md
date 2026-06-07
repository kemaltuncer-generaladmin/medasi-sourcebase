# SourceBase Backend Handoff

Bu klasor artik hem Swift ana projeyi hem de SourceBase backend dosya setini tasir.

## Kaynak Seti

- `SourceBaseBackend/`: Swift uygulamasinin backend client/domain paketi. Bu paket Cardstation'daki paketten daha guncel oldugu icin korunur.
- `supabase/functions/sourcebase/`: Drive, upload session, complete upload, generation job ve sonuc action'larini sunan Edge Function.
- `supabase/functions/ai-services/`: AI servis endpointleri.
- `supabase/migrations/`: SourceBase tablo, storage, wallet, AI job ve S3 kolon migration'lari.
- `supabase/config.toml`, `supabase/import_map.json`, `supabase/deno.json`: Supabase runtime ayarlari.
- `Dockerfile`: Coolify'in repo kokunden build alabilmesi icin backend-only health container.
- `scripts/backend/`: Coolify status/deploy yardimci scriptleri.
- `docs/backend/`: Backend ve deploy notlari.
- `test/fixtures/sourcebase/`: Deno extraction test fixture'lari.
- `tools/`: Local storage panel ve SSH tunnel yardimcilari.

## Secret Kurali

Gercek secret degerleri sadece local `.env`, Supabase secret store veya Coolify environment icinde tutulur. Tracked dosyalarda service role key, S3 secret, Coolify token, GitHub token veya Vertex JSON bulunmamalidir.

Gerekli local/Coolify env basliklari:

```bash
SOURCEBASE_SUPABASE_URL
SOURCEBASE_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SOURCEBASE_STORAGE_DRIVER=s3
SOURCEBASE_S3_ENDPOINT
SOURCEBASE_S3_BUCKET
SOURCEBASE_S3_REGION
SOURCEBASE_S3_ACCESS_KEY
SOURCEBASE_S3_SECRET_KEY
SOURCEBASE_COOLIFY_URL
SOURCEBASE_COOLIFY_APP_UUID
SOURCEBASE_COOLIFY_API_KEY
SOURCEBASE_DEPLOY_WEBHOOK
```

## Push ve Coolify

Coolify mevcutta `https://github.com/kemaltuncer-generaladmin/medasi-sourcebase.git` reposunu izler. Push sonrasi otomatik deploy icin Coolify'in izledigi branch'e push edilmelidir. Mevcut production branch `git-docker-coolify` ise yerel commit su sekilde yayinlanir:

```bash
git push origin HEAD:git-docker-coolify
```

Manuel tetikleme gerekirse:

```bash
python3 scripts/backend/deploy.py
python3 scripts/backend/check_deployment.py
```

## Dogrulama

```bash
deno test --no-check --allow-all supabase/functions/**/*.test.ts
swift test --package-path SourceBaseBackend
swift test --package-path SourceBaseiOS
xcodebuild -project App/SourceBase.xcodeproj -scheme SourceBase -configuration Debug -destination 'generic/platform=iOS Simulator' build
```
