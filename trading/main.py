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

from brokers import create_api
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
    """감시 종목 조회 우선순위:
    1. 사용자 지정 trading_watchlist
    2. 최신 스크리닝 결과 상위 5종목 (2일 이내)
    3. 하드코딩 fallback
    """
    # 1. 사용자 지정 watchlist
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

    # 2. 최신 스크리닝 결과 상위 5종목
    try:
        from datetime import datetime, timedelta, timezone
        cutoff = (datetime.now(timezone.utc) - timedelta(days=2)).strftime('%Y-%m-%dT%H:%M:%SZ')
        r = requests.get(
            f"{_SUPABASE_URL}/rest/v1/screening_results"
            f"?pass=eq.true&screened_at=gte.{cutoff}&order=score.desc&limit=5",
            headers=_supabase_headers(),
            timeout=10,
        )
        picks = r.json() if r.ok else []
        if picks:
            print(f"📋 스크리닝 상위 {len(picks)}종목 사용: "
                  f"{', '.join(p['stock_name'] for p in picks)}")
            return [{'code': p['stock_code'], 'name': p['stock_name']} for p in picks]
    except Exception:
        pass

    return []


def is_market_open() -> bool:
    """KST 기준 거래 가능 시간 여부 (NXT 포함)
    프리마켓 08:00~09:00 / 정규장 09:00~15:30 / 포스트마켓 15:40~20:00
    """
    from datetime import time as _time
    kst = pytz.timezone('Asia/Seoul')
    now = datetime.now(kst)
    if now.weekday() >= 5:
        return False
    t = now.time()
    return _time(9, 0) <= t <= _time(15, 20)  # 정규장 (마감 10분 전 컷)


def run_for_user(user_cfg: dict) -> str:
    """한 사용자에 대한 전략 실행. 결과 텍스트 반환."""
    buf = StringIO()

    broker = user_cfg.get('broker_type', 'kis')
    api = create_api(broker, user_cfg)
    try:
        api.auth()
    except Exception as e:
        return f"❌ [{broker}] 인증 실패: {e}\n"

    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M:%S KST')
    buf.write(f"\n{'='*60}\n")
    buf.write(f"  StockWiki 자동매매  |  {now_str}\n")
    buf.write(f"{'='*60}\n")

    watchlist = _fetch_watchlist(user_cfg.get('user_id', ''))
    if not watchlist:
        buf.write("⏸  스크리닝 통과 종목 없음 — 매매 건너뜀\n")
        return buf.getvalue()

    errors = []
    for stock in watchlist:
        try:
            # strategy.run은 sys.stdout에 출력 → buf로 리다이렉트
            _orig = sys.stdout
            sys.stdout = _TeeWriter(_orig, buf)
            strategy.run(api, stock['code'], stock['name'], user_cfg)
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

    any_trade = False
    for user_cfg in users:
        notify_email_addr = user_cfg.get('notify_email') or ''
        print(f"\n▶ 사용자: {notify_email_addr or user_cfg.get('user_id', '?')}")

        content = run_for_user(user_cfg)

        # 실제 매수 체결 또는 오류가 있을 때만 알림 발송
        has_trade = '진입 확정' in content or '% 도달 →' in content
        has_error = '❌' in content
        if has_trade or has_error:
            any_trade = True
            if notify_email_addr:
                email_notify.send_to(content, recipients=[notify_email_addr])

    if any_trade:
        summary = f"[{now_str}] 자동매매 체결 — 사용자 {len(users)}명"
        kakao_notify.send(summary)
        print("✅ 전체 완료 (알림 발송)")
    else:
        print("✅ 전체 완료 (매수 없음 — 알림 생략)")


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
