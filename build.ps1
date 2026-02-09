# Flutter 웹 빌드 스크립트 (PowerShell)

Write-Host "🔧 Flutter 의존성 설치 중..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter pub get 실패" -ForegroundColor Red
    exit 1
}

Write-Host "🏗️ Flutter 웹 빌드 중..." -ForegroundColor Cyan
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter 빌드 실패" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 빌드 완료!" -ForegroundColor Green

