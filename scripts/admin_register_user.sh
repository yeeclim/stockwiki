#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SUPABASE_FUNCTIONS_URL:-}" ]; then
  echo "Set SUPABASE_FUNCTIONS_URL environment variable (e.g. https://<project>.functions.supabase.co)"
  exit 1
fi
if [ -z "${ADMIN_API_KEY:-}" ]; then
  echo "Set ADMIN_API_KEY environment variable"
  exit 1
fi

USER_ID=${1:-}
if [ -z "$USER_ID" ]; then
  echo "Usage: $0 <user_id> [kis_app_key] [kis_app_secret] [acct_no] [daily_max_buy]"
  exit 1
fi

KIS_KEY=${2:-P5...}
KIS_SECRET=${3:-secret}
ACCT_NO=${4:-00000000}
DAILY_MAX=${5:-}

payload=$(jq -n --arg uid "$USER_ID" --arg k "$KIS_KEY" --arg s "$KIS_SECRET" --arg a "$ACCT_NO" --argjson d ${DAILY_MAX:-null} '{user_id: $uid, kis_app_key: $k, kis_app_secret: $s, kis_account_no: $a, daily_max_buy: ($d)}')

curl -sS -X POST "$SUPABASE_FUNCTIONS_URL/admin-register-to-github" \
  -H "Content-Type: application/json" \
  -H "x-admin-secret: $ADMIN_API_KEY" \
  -d "$payload" | jq
