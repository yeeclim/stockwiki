@echo off
REM KRX 데이터 자동 업데이트 시작 스크립트
REM 매일 밤 12시에 KRX 데이터를 자동으로 업데이트

echo KRX 데이터 자동 업데이트 스케줄러 시작
echo 실행 시간: %date% %time%
echo.

REM Python 스크립트 실행
cd /d "%~dp0"
python auto_krx_scheduler.py --daemon

echo.
echo KRX 데이터 스케줄러 종료
pause
