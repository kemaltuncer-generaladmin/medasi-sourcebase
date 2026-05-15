# SourceBase Edge Function

This function belongs only to SourceBase. Do not merge it with the existing Qlinik Edge Function.

## Actions

- `drive_bootstrap`: checks SourceBase Drive server readiness.
- `create_upload_session`: creates a short-lived Google Cloud Storage signed PUT URL.
- `complete_upload`: validates that the uploaded object belongs to the authenticated user and returns the next processing step.

## Required Server Environment

Set these in the SourceBase Supabase/Coolify server environment only:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` for future DB writes, never in Flutter
- `SOURCEBASE_GCS_BUCKET`
- `SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON`
- `SOURCEBASE_ALLOWED_ORIGIN`

`SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON` must be the raw service-account JSON string. Keep it out of Git and out of Flutter build args.

## GCS Bucket CORS

The bucket must allow SourceBase web origins to send `PUT` with `Content-Type` to signed URLs. Example policy:

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
