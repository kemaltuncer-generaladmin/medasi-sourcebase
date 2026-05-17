#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/veyselkemal/Developer/flutterv2/flutter_sdk_3_41_9/bin/flutter}"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
  set +a
fi

SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_ANON_KEY:-${SOURCEBASE_SUPABASE_PUBLIC_TOKEN:-}}"
SOURCEBASE_PUBLIC_URL="${SOURCEBASE_PUBLIC_URL:-https://sourcebase.medasi.com.tr}"
BUILD_NAME="${BUILD_NAME:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-4}"

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
"$FLUTTER_BIN" build ipa --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=SOURCEBASE_SUPABASE_URL="$SOURCEBASE_SUPABASE_URL" \
  --dart-define=SOURCEBASE_SUPABASE_ANON_KEY="$SOURCEBASE_SUPABASE_ANON_KEY" \
  --dart-define=SOURCEBASE_PUBLIC_URL="$SOURCEBASE_PUBLIC_URL"
