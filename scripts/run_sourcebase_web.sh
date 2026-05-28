#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
SDK_ROOT="${SDK_ROOT:-$HOME/SDKlar}"
if [[ ! -d "$SDK_ROOT" ]]; then
  SDK_ROOT="$(find "$HOME" -maxdepth 1 -type d -name "SDK*lar" | head -n 1)"
fi
if [[ -n "$SDK_ROOT" && -x "$SDK_ROOT/flutter/current/bin/flutter" ]]; then
  FLUTTER_BIN="${FLUTTER_BIN:-$SDK_ROOT/flutter/current/bin/flutter}"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_ANON_KEY:-${SOURCEBASE_SUPABASE_PUBLIC_TOKEN:-}}"
SOURCEBASE_PUBLIC_URL="${SOURCEBASE_PUBLIC_URL:-http://localhost:8088}"
SOURCEBASE_GOOGLE_OAUTH_ENABLED="${SOURCEBASE_GOOGLE_OAUTH_ENABLED:-false}"
SOURCEBASE_APPLE_OAUTH_ENABLED="${SOURCEBASE_APPLE_OAUTH_ENABLED:-false}"

missing=()
[[ -n "${SOURCEBASE_SUPABASE_URL:-}" ]] || missing+=("SOURCEBASE_SUPABASE_URL")
[[ -n "$SOURCEBASE_SUPABASE_ANON_KEY" ]] || missing+=("SOURCEBASE_SUPABASE_ANON_KEY")

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required SourceBase Flutter env vars: %s\n' "${missing[*]}" >&2
  printf 'Add them to %s or export them before running this script.\n' "$ENV_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"
"$FLUTTER_BIN" run -d chrome \
  --web-port=8088 \
  --dart-define=SOURCEBASE_SUPABASE_URL="$SOURCEBASE_SUPABASE_URL" \
  --dart-define=SOURCEBASE_SUPABASE_ANON_KEY="$SOURCEBASE_SUPABASE_ANON_KEY" \
  --dart-define=SOURCEBASE_SUPABASE_PUBLIC_TOKEN="$SOURCEBASE_SUPABASE_ANON_KEY" \
  --dart-define=SOURCEBASE_PUBLIC_URL="$SOURCEBASE_PUBLIC_URL" \
  --dart-define=SOURCEBASE_GOOGLE_OAUTH_ENABLED="$SOURCEBASE_GOOGLE_OAUTH_ENABLED" \
  --dart-define=SOURCEBASE_APPLE_OAUTH_ENABLED="$SOURCEBASE_APPLE_OAUTH_ENABLED" \
  "$@"
