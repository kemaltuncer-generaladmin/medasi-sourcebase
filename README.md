# MedAsi CardStation

CardStation is the flashcard application for the MedAsi ecosystem. It is developed as a separate product and repository so Qlinik production code, deploy flow, database objects, and secrets stay isolated.

## Getting Started

This project is a Flutter application.

## Docker Deployment

CardStation is deployed as its own Docker application. It must not share a Dockerfile, build context, environment variable set, or Coolify application UUID with Qlinik.

Coolify application settings:

- Repository: `kemaltuncer-generaladmin/medasi-cardstation`
- Branch: `main`
- Build pack/type: `Dockerfile`
- Dockerfile path: `Dockerfile`
- Exposed port: `80`

The image builds Flutter web assets and serves them with Nginx. Secrets must stay in Coolify environment variables or local `.env` files that are not committed.

Useful Flutter resources:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
