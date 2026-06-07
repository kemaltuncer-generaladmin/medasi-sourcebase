# SourceBase Edge Function

This function belongs only to SourceBase. Do not merge it with the existing
Qlinik Edge Function.

## Actions

- `drive_bootstrap`: checks SourceBase Drive server readiness.
- `create_upload_session`: creates a short-lived S3-compatible signed PUT URL.
- `complete_upload`: validates that the uploaded object belongs to the
  authenticated user and returns the next processing step.

## Required Server Environment

Set these in the SourceBase Supabase/Coolify server environment only:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` for future DB writes, never in Flutter
- `SOURCEBASE_STORAGE_DRIVER=s3`
- `SOURCEBASE_S3_ENDPOINT`
- `SOURCEBASE_S3_BUCKET`
- `SOURCEBASE_S3_REGION`
- `SOURCEBASE_S3_ACCESS_KEY`
- `SOURCEBASE_S3_SECRET_KEY`
- `SOURCEBASE_ALLOWED_ORIGIN`
- `VERTEX_PROJECT_ID`
- `VERTEX_LOCATION`
- `VERTEX_MODEL`
- `VERTEX_SERVICE_ACCOUNT_JSON`
- `TEXT_PROVIDER_DEFAULT`
- `TEXT_MODEL_CHEAP`
- `TEXT_MODEL_STANDARD`
- `TEXT_MODEL_REASONING`
- `TEXT_MODEL_REVIEWER`
- `IMAGE_PROVIDER_DEFAULT`
- `IMAGE_MODEL_DRAFT`
- `IMAGE_MODEL_PREMIUM`
- `IMAGE_PROVIDER_FALLBACK`
- `IMAGE_MODEL_FALLBACK`
- `OPENAI_API_KEY` optional, server-side only
- `ANTHROPIC_API_KEY` optional, server-side only
- `STABILITY_API_KEY` optional, server-side only
- `MC_TL_VALUE` default `3.5`
- `TARGET_GROSS_MARGIN` default `0.70`
- `MIN_MC_UNIT` default `0.05`
- `MC_MICRO_PRICING_ENABLED` default `true`

S3 credentials, service role keys, and AI provider keys must stay server-side
and must not be passed to Flutter build args.

## S3 Bucket CORS

The bucket must allow SourceBase web origins to send `PUT` with `Content-Type`
to signed URLs. Example policy:

```json
[
  {
    "origin": ["https://sourcebase.medasi.com.tr", "http://localhost:8088"],
    "method": ["PUT", "GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```
