FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG SOURCEBASE_SUPABASE_URL=""
ARG SOURCEBASE_SUPABASE_PUBLIC_TOKEN=""
ARG SOURCEBASE_PUBLIC_URL=""
RUN flutter build web --release \
  --dart-define=SOURCEBASE_SUPABASE_URL="${SOURCEBASE_SUPABASE_URL}" \
  --dart-define=SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_PUBLIC_TOKEN}" \
  --dart-define=SOURCEBASE_PUBLIC_URL="${SOURCEBASE_PUBLIC_URL}"

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
