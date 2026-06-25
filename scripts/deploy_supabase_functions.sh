#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_REF:-}" ]; then
  echo "Set PROJECT_REF environment variable (Supabase project ref)"
  exit 1
fi

echo "Deploying functions to Supabase project: $PROJECT_REF"
supabase functions deploy register-to-github --project-ref "$PROJECT_REF"
supabase functions deploy admin-register-to-github --project-ref "$PROJECT_REF"
supabase functions deploy market-data --project-ref "$PROJECT_REF"

echo "Done."
