#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
DEPLOY_FUNCTION="${DEPLOY_FUNCTION:-0}"

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'Env file not found: %s\n' "$ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

SOURCEBASE_SUPABASE_ANON_KEY="${SOURCEBASE_SUPABASE_ANON_KEY:-${SOURCEBASE_SUPABASE_PUBLIC_TOKEN:-}}"
VERTEX_LOCATION="${VERTEX_LOCATION:-us-central1}"
VERTEX_MODEL="${VERTEX_MODEL:-gemini-2.5-flash}"

required=(
  "SOURCEBASE_SUPABASE_URL"
  "SOURCEBASE_SUPABASE_ANON_KEY"
  "SOURCEBASE_GCS_BUCKET"
  "VERTEX_PROJECT_ID"
  "SUPABASE_SERVICE_ROLE_KEY"
)

missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done

if [[ -z "${SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON:-}" && -z "${GOOGLE_SERVICE_ACCOUNT_JSON:-}" ]]; then
  missing+=("SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON")
fi

if [[ -z "${VERTEX_SERVICE_ACCOUNT_JSON:-}" && -z "${GOOGLE_SERVICE_ACCOUNT_JSON:-}" ]]; then
  missing+=("VERTEX_SERVICE_ACCOUNT_JSON")
fi

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required Supabase/Google Cloud env vars: %s\n' "${missing[*]}" >&2
  printf 'Add them to %s, then rerun this script.\n' "$ENV_FILE" >&2
  exit 1
fi

tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT

{
  printf 'SUPABASE_URL=%q\n' "$SOURCEBASE_SUPABASE_URL"
  printf 'SUPABASE_ANON_KEY=%q\n' "$SOURCEBASE_SUPABASE_ANON_KEY"
  printf 'SUPABASE_SERVICE_ROLE_KEY=%q\n' "$SUPABASE_SERVICE_ROLE_KEY"
  printf 'SOURCEBASE_ALLOWED_ORIGIN=%q\n' "${SOURCEBASE_ALLOWED_ORIGIN:-${SOURCEBASE_PUBLIC_URL:-https://sourcebase.medasi.com.tr}}"
  printf 'SOURCEBASE_GCS_BUCKET=%q\n' "$SOURCEBASE_GCS_BUCKET"
  [[ -z "${SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON:-}" ]] || printf 'SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON=%q\n' "$SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON"
  [[ -z "${VERTEX_SERVICE_ACCOUNT_JSON:-}" ]] || printf 'VERTEX_SERVICE_ACCOUNT_JSON=%q\n' "$VERTEX_SERVICE_ACCOUNT_JSON"
  [[ -z "${GOOGLE_SERVICE_ACCOUNT_JSON:-}" ]] || printf 'GOOGLE_SERVICE_ACCOUNT_JSON=%q\n' "$GOOGLE_SERVICE_ACCOUNT_JSON"
  printf 'VERTEX_PROJECT_ID=%q\n' "$VERTEX_PROJECT_ID"
  printf 'VERTEX_LOCATION=%q\n' "$VERTEX_LOCATION"
  printf 'VERTEX_MODEL=%q\n' "$VERTEX_MODEL"
} > "$tmp_env"

supabase secrets set --env-file "$tmp_env"

if [[ "$DEPLOY_FUNCTION" == "1" ]]; then
  supabase functions deploy sourcebase --use-api
fi

printf 'SourceBase Supabase secrets are configured.\n'
