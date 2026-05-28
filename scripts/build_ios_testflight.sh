#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${SDK_ROOT:-$HOME/SDKlar}"
if [[ ! -d "$SDK_ROOT" ]]; then
  SDK_ROOT="$(find "$HOME" -maxdepth 1 -type d -name "SDK*lar" | head -n 1)"
fi
if [[ -n "$SDK_ROOT" && -x "$SDK_ROOT/flutter/current/bin/flutter" ]]; then
  FLUTTER_BIN="${FLUTTER_BIN:-$SDK_ROOT/flutter/current/bin/flutter}"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
  set +a
fi

SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_ANON_KEY:-${SOURCEBASE_SUPABASE_PUBLIC_TOKEN:-}}"
SOURCEBASE_PUBLIC_URL="${SOURCEBASE_PUBLIC_URL:-https://sourcebase.medasi.com.tr}"
SOURCEBASE_MOBILE_REDIRECT_URL="${SOURCEBASE_MOBILE_REDIRECT_URL:-sourcebase://auth/callback}"
SOURCEBASE_GOOGLE_OAUTH_ENABLED="${SOURCEBASE_GOOGLE_OAUTH_ENABLED:-false}"
SOURCEBASE_APPLE_OAUTH_ENABLED="${SOURCEBASE_APPLE_OAUTH_ENABLED:-false}"
BUILD_NAME="${BUILD_NAME:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-9}"

missing=()
[[ -n "${SOURCEBASE_SUPABASE_URL:-}" ]] || missing+=("SOURCEBASE_SUPABASE_URL")
[[ -n "$SOURCEBASE_SUPABASE_ANON_KEY" ]] || missing+=("SOURCEBASE_SUPABASE_ANON_KEY")

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required iOS build env vars: %s\n' "${missing[*]}" >&2
  printf 'Add them to .env or export them before running this script.\n' >&2
  exit 1
fi

cd "$ROOT_DIR"
find . -path './.git' -prune -o -name '._*' -type f -delete

printf 'Refreshing Flutter iOS generated artifacts...\n'
rm -rf build/ios ios/Pods ios/.symlinks ios/Flutter/ephemeral
"$FLUTTER_BIN" pub get

printf 'Building iOS archive for TestFlight...\n'
"$FLUTTER_BIN" build ipa --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=SOURCEBASE_SUPABASE_URL="$SOURCEBASE_SUPABASE_URL" \
  --dart-define=SOURCEBASE_SUPABASE_ANON_KEY="$SOURCEBASE_SUPABASE_ANON_KEY" \
  --dart-define=SOURCEBASE_SUPABASE_PUBLIC_TOKEN="$SOURCEBASE_SUPABASE_ANON_KEY" \
  --dart-define=SOURCEBASE_PUBLIC_URL="$SOURCEBASE_PUBLIC_URL" \
  --dart-define=SOURCEBASE_MOBILE_REDIRECT_URL="$SOURCEBASE_MOBILE_REDIRECT_URL" \
  --dart-define=SOURCEBASE_GOOGLE_OAUTH_ENABLED="$SOURCEBASE_GOOGLE_OAUTH_ENABLED" \
  --dart-define=SOURCEBASE_APPLE_OAUTH_ENABLED="$SOURCEBASE_APPLE_OAUTH_ENABLED"
