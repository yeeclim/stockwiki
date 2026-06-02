"""
자동매매 메인 실행 파일
GitHub Actions에서 장중 5분마다 호출됨.

Supabase trading_configs 테이블에서 is_active=true인 모든 사용자 설정을 읽어
각 사용자의 KIS API로 전략을 실행하고, 결과를 이메일로 발송합니다.
"""
import sys
import os
import traceback
from datetime import datetime
from io import StringIO
import pytz
import requests

from kis_api import KISApi
import strategy
import kakao_notify
import email_notify

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()


def _supabase_headers():
    return {
        'apikey':        _SUPABASE_KEY,
        'Authorization': f'Bearer {_SUPABASE_KEY}',
        'Content-Type':  'application/json',
    }


def _fetch_active_users() -> list[dict]:
    """trading_configs에서 활성 사용자 설정 전체 조회"""
    r = requests.get(
        f"{_SUPABASE_URL}/rest/v1/trading_configs?is_active=eq.true",
        headers=_supabase_headers(),
        timeout=10,
    )
    r.raise_for_status()
    return r.json()


def _fetch_watchlist(user_id: str) -> list[dict]:
    """사용자별 감시 종목 조회 (trading_watchlist 테이블)
    없으면 기본 WATCHLIST 반환"""
    try:
        r = requests.get(
            f"{_SUPABASE_URL}/rest/v1/trading_watchlist"
            f"?user_id=eq.{user_id}&is_active=eq.true",
            headers=_supabase_headers(),
            timeout=10,
        )
        items = r.json() if r.ok else []
        if items:
            return [{'code': w['stock_code'], 'name': w['stock_name']} for w in items]
    except Exception:
        pass
    # fallback: 기존 하드코딩 목록
    return [
        {'code': '096350', 'name': '대창솔루션'},
        {'code': '079550', 'name': 'LIG디펜스앤에어로스페이스'},
    ]


def is_market_open() -> bool:
    """KST 기준 장중 시간 여부 (평일 09:00~15:30)"""
    kst  = pytz.timezone('Asia/Seoul')
    now  = datetime.now(kst)
    if now.weekday() >= 5:
        return False
    open_  = now.replace(hour=9,  minute=0,  second=0, microsecond=0)
    close_ = now.replace(hour=15, minute=30, second=0, microsecond=0)
    return open_ <= now <= close_


def run_for_user(user_cfg: dict) -> str:
    """한 사용자에 대한 전략 실행. 결과 텍스트 반환."""
    buf = StringIO()

    # KIS API 키를 환경변수로 임시 설정
    os.environ['KIS_APP_KEY']         = user_cfg['kis_app_key']
    os.environ['KIS_APP_SECRET']      = user_cfg['kis_app_secret']
    os.environ['KIS_ACCOUNT_NO']      = user_cfg['kis_account_no']
    os.environ['KIS_ACCOUNT_PROD_CODE'] = user_cfg.get('kis_account_prod_code', '01')

    api = KISApi()
    try:
        api.auth()
    except Exception as e:
        return f"❌ KIS 인증 실패: {e}\n"

    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M:%S KST')
    buf.write(f"\n{'='*60}\n")
    buf.write(f"  StockWiki 자동매매  |  {now_str}\n")
    buf.write(f"{'='*60}\n")

    watchlist = _fetch_watchlist(user_cfg.get('user_id', ''))
    errors = []
    for stock in watchlist:
        try:
            # strategy.run은 sys.stdout에 출력 → buf로 리다이렉트
            _orig = sys.stdout
            sys.stdout = _TeeWriter(_orig, buf)
            strategy.run(api, stock['code'], stock['name'])
            sys.stdout = _orig
        except Exception as e:
            sys.stdout = sys.__stdout__
            msg = f"[{stock['name']}] {e}"
            buf.write(f"\n❌ {msg}\n")
            traceback.print_exc()
            errors.append(msg)

    if errors:
        buf.write(f"\n⚠️  오류 {len(errors)}건:\n")
        for err in errors:
            buf.write(f"   - {err}\n")

    return buf.getvalue()


def main():
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M:%S KST')

    print(f"\n{'='*60}")
    print(f"  StockWiki 자동매매  |  {now_str}")
    print(f"{'='*60}")

    if not is_market_open():
        print("⏸  장외 시간 → 종료")
        sys.exit(0)

    # ── 활성 사용자 목록 조회 ────────────────────────────────────────────────
    try:
        users = _fetch_active_users()
    except Exception as e:
        print(f"❌ 사용자 설정 조회 실패: {e}")
        sys.exit(1)

    if not users:
        print("⚠️  등록된 활성 사용자가 없습니다.")
        sys.exit(0)

    print(f"👤 활성 사용자 {len(users)}명 처리 시작")

    all_errors = False
    for user_cfg in users:
        notify_email_addr = user_cfg.get('notify_email') or ''
        print(f"\n▶ 사용자: {notify_email_addr or user_cfg.get('user_id', '?')}")

        content = run_for_user(user_cfg)
        print(content)

        # 이메일 알림 (사용자별)
        if notify_email_addr:
            email_notify.send_to(content, recipients=[notify_email_addr])

    # 관리자(나)에게는 카카오 + 요약 이메일
    summary = f"[{now_str}] 자동매매 완료 — 사용자 {len(users)}명 처리"
    kakao_notify.send(summary)

    if all_errors:
        sys.exit(1)
    else:
        print("✅ 전체 완료")


class _TeeWriter:
    def __init__(self, original, buffer):
        self._orig = original
        self._buf  = buffer

    def write(self, data):
        self._orig.write(data)
        self._buf.write(data)

    def flush(self):
        self._orig.flush()
        self._buf.flush()


if __name__ == '__main__':
    main()
