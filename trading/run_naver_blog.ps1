# 네이버 블로그 로컬 자동 포스팅 실행 스크립트
#
# 사용법:
#   1. 아래 ANON_KEY = "" 사이 따옴표 안에 Supabase anon key를 붙여넣고 저장
#      (supabase.com 프로젝트 > Project Settings > API > anon public 키)
#   2. PowerShell에서:  .\run_naver_blog.ps1

$ANON_KEY = ""

if ($ANON_KEY -eq "") {
    Write-Host "먼저 이 파일을 열어서 3번째 줄 ANON_KEY = `"`" 사이에 anon key를 붙여넣고 저장하세요." -ForegroundColor Red
    exit 1
}

$env:SUPABASE_URL = "https://xpiqctjidvrlmazslzyg.supabase.co"
$env:SUPABASE_ANON_KEY = $ANON_KEY
$env:NAVER_CHROME_USER_DATA_DIR = "C:\Users\Lee.SeungHwan.FSOFT.FPT.VN\AppData\Local\StockWikiNaverAutomation\ChromeProfile"
$env:NAVER_CHROME_PROFILE = "Default"

python naver_blog_local.py
