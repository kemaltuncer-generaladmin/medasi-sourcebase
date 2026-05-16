# MedAsi SourceBase

SourceBase is the flashcard application for the MedAsi ecosystem. It is developed as a separate product and repository so Qlinik production code, deploy flow, database objects, and secrets stay isolated.

## Getting Started

This project is a Flutter application.

## Docker Deployment

SourceBase is deployed as its own Docker application. It must not share a Dockerfile, build context, environment variable set, or Coolify application UUID with Qlinik.

Coolify application settings:

- Repository: `kemaltuncer-generaladmin/medasi-sourcebase`
- Branch: `main`
- Build pack/type: `Dockerfile`
- Dockerfile path: `Dockerfile`
- Exposed port: `80`

The image builds Flutter web assets and serves them with Nginx. Secrets must stay in Coolify environment variables or local `.env` files that are not committed.

Required public build arguments:

- `SOURCEBASE_SUPABASE_URL`
- `SOURCEBASE_SUPABASE_PUBLIC_TOKEN`
- `SOURCEBASE_PUBLIC_URL`

`SOURCEBASE_SUPABASE_PUBLIC_TOKEN` is passed into Flutter as `SOURCEBASE_SUPABASE_ANON_KEY` during the Docker build. These values connect SourceBase to the same shared MedAsi Supabase backend/Auth user pool as Qlinik. In production this backend can be exposed through the shared Supabase custom API domain `https://medasi.com.tr`; `https://sourcebase.medasi.com.tr` is the SourceBase web app/origin, not a separate database. Do not use `service_role` keys in Flutter, Docker build args, or browser code.

## Auth Boundary

SourceBase uses the shared MedAsi Supabase Auth pool so a user created in Qlinik can sign in here, and a user created here exists in the same Auth pool for Qlinik. SourceBase signups include `app_code=sourcebase` in user metadata, but this app does not write to Qlinik tables or Qlinik Edge Functions.

Email verification and password reset requests use `SOURCEBASE_PUBLIC_URL` as the redirect target. If Qlinik and SourceBase need different email HTML/templates inside the same Supabase project, configure Supabase Auth with an app-aware custom email hook/template router; the built-in project-level templates are shared unless routed server-side.

Useful Flutter resources:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
