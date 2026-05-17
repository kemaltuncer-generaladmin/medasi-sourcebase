# SourceBase GCS + Vertex Edge Configuration

This setup is server-side only. Do not pass these values to Flutter build args.

## Required Supabase Secrets

Set these on the Supabase project that hosts the `sourcebase` Edge Function:

```bash
supabase secrets set \
  SOURCEBASE_GCS_BUCKET="sourcebase-sources" \
  SOURCEBASE_ALLOWED_ORIGIN="https://sourcebase.medasi.com.tr" \
  SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"..."}' \
  VERTEX_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"..."}' \
  VERTEX_PROJECT_ID="your-gcp-project-id" \
  VERTEX_LOCATION="us-central1" \
  VERTEX_MODEL="gemini-2.5-flash"
```

`GOOGLE_SERVICE_ACCOUNT_JSON` is only a local/dev fallback. Production should
keep GCS and Vertex separated with the two service-specific secret names above.

## GCS Bucket CORS

Apply the CORS policy so browser PUT uploads to signed URLs work:

```bash
gcloud storage buckets update gs://sourcebase-sources \
  --cors-file=supabase/functions/sourcebase/gcs-cors.json
```

## Service Account Permissions

The GCS service account needs:

- `roles/storage.objectAdmin` on the SourceBase bucket

The Vertex service account needs:

- `roles/aiplatform.user` on the Vertex AI project

## Runtime Check

Call the `runtime_config` action with an authenticated user token. It returns
only booleans/model/location, never secret values.
