Param(
  [Parameter(Mandatory=$true)][string]$UserId,
  [string]$KisKey = 'P5...',
  [string]$KisSecret = 'secret',
  [string]$AcctNo = '00000000',
  [int]$DailyMax = 0
)
if (-not $env:SUPABASE_FUNCTIONS_URL) {
  Write-Error "Set SUPABASE_FUNCTIONS_URL environment variable"
  exit 1
}
if (-not $env:ADMIN_API_KEY) {
  Write-Error "Set ADMIN_API_KEY environment variable"
  exit 1
}

$payload = @{
  user_id = $UserId
  kis_app_key = $KisKey
  kis_app_secret = $KisSecret
  kis_account_no = $AcctNo
}
if ($DailyMax -gt 0) { $payload.daily_max_buy = $DailyMax }

$json = $payload | ConvertTo-Json -Depth 4

Invoke-RestMethod -Uri "$($env:SUPABASE_FUNCTIONS_URL)/admin-register-to-github" -Method Post -Headers @{ 'x-admin-secret' = $env:ADMIN_API_KEY } -ContentType 'application/json' -Body $json | ConvertTo-Json -Depth 6
