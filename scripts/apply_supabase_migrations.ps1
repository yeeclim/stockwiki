Param(
  [string]$ProjectRef
)
if (-not $ProjectRef) {
  if (-not $env:PROJECT_REF) {
    Write-Error "Provide -ProjectRef or set PROJECT_REF environment variable"
    exit 1
  }
  $ProjectRef = $env:PROJECT_REF
}

Write-Output "Applying migrations to Supabase project: $ProjectRef"

$migs = @("supabase/migrations/20260609_add_kakao_notify.sql", "supabase/migrations/20260609_add_daily_max_buy.sql")
foreach ($f in $migs) {
  if (Test-Path $f) {
    Write-Output "Applying $f"
    supabase db query --file $f --project-ref $ProjectRef
  } else {
    Write-Warning "Migration file not found: $f"
  }
}

Write-Output "Done."
