#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_REF:-}" ]; then
  echo "Set PROJECT_REF environment variable (Supabase project ref)"
  exit 1
fi

echo "Applying SQL migrations to Supabase project: $PROJECT_REF"

MIGS=(
  "supabase/migrations/20260609_add_kakao_notify.sql"
  "supabase/migrations/20260609_add_daily_max_buy.sql"
)

for f in "${MIGS[@]}"; do
  if [ -f "$f" ]; then
    echo "Applying $f"
    supabase db query --file "$f" --project-ref "$PROJECT_REF"
  else
    echo "Warning: migration file not found: $f"
  fi
done

echo "Done."
