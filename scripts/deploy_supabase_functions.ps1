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

Write-Output "Deploying functions to Supabase project: $ProjectRef"
supabase functions deploy register-to-github --project-ref $ProjectRef
supabase functions deploy admin-register-to-github --project-ref $ProjectRef

Write-Output "Done."
