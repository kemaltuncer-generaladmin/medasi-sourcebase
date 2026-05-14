FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG CARDSTATION_SUPABASE_URL=""
ARG CARDSTATION_SUPABASE_PUBLIC_TOKEN=""
ARG CARDSTATION_PUBLIC_URL=""
RUN flutter build web --release \
  --dart-define=CARDSTATION_SUPABASE_URL="${CARDSTATION_SUPABASE_URL}" \
  --dart-define=CARDSTATION_SUPABASE_ANON_KEY="${CARDSTATION_SUPABASE_PUBLIC_TOKEN}" \
  --dart-define=CARDSTATION_PUBLIC_URL="${CARDSTATION_PUBLIC_URL}"

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
