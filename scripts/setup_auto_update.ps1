# KRX 데이터 자동 업데이트를 위한 Windows 작업 스케줄러 설정
# PowerShell 관리자 권한으로 실행 필요

Write-Host "KRX 데이터 자동 업데이트 작업 스케줄러 설정" -ForegroundColor Green
Write-Host "=" * 50

# 작업 스케줄러에 작업 생성
$TaskName = "KRX Data Auto Update"
$ScriptPath = Join-Path $PSScriptRoot "auto_krx_scheduler.py"
$WorkingDir = $PSScriptRoot
$PythonPath = "python"

try {
    # 기존 작업이 있으면 삭제
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Host "기존 작업 삭제 중..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # 새 작업 생성
    Write-Host "새 작업 생성 중..." -ForegroundColor Blue
    
    $Action = New-ScheduledTaskAction -Execute $PythonPath -Argument "auto_krx_scheduler.py --daemon" -WorkingDirectory $WorkingDir
    $Trigger = New-ScheduledTaskTrigger -Daily -At "00:00"
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description "매일 밤 12시에 KRX 데이터 자동 업데이트"
    
    Write-Host "작업 스케줄러 설정 완료!" -ForegroundColor Green
    Write-Host "실행 스케줄: 매일 밤 12시 (00:00)" -ForegroundColor Cyan
    Write-Host "실행 파일: $ScriptPath" -ForegroundColor Cyan
    
    # 작업 상태 확인
    $Task = Get-ScheduledTask -TaskName $TaskName
    Write-Host "작업 상태: $($Task.State)" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "작업 관리 방법:" -ForegroundColor Magenta
    Write-Host "  - 작업 스케줄러에서 'KRX Data Auto Update' 작업 확인"
    Write-Host "  - 수동 실행: 작업 스케줄러에서 '실행' 클릭"
    Write-Host "  - 작업 삭제: 작업 스케줄러에서 '삭제' 클릭"
    Write-Host "  - 로그 확인: scripts 폴더의 krx_auto_scheduler.log 파일"
    
} catch {
    Write-Host "작업 스케줄러 설정 실패: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "관리자 권한으로 PowerShell을 실행해주세요." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
