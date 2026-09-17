"""
Supabase REST API 연동 (포지션 상태 + 거래 로그)

포지션 상태(trading_positions)는 사용자별이다. 예전엔 stock_code 로만 조회·저장해서
두 사용자가 같은 종목을 들고 있으면 물타기 완료 플래그를 서로 덮어썼다.
(user_id, stock_code) 유니크 제약은 마이그레이션 20260917000001 에서 만든다.
"""
import os
from datetime import datetime, timedelta, timezone

import requests

_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').replace('\n', '').strip()
_TIMEOUT = 10
_KST = timezone(timedelta(hours=9))

_DEFAULT_FLAGS = {
    'sell_5_done':      False,
    'sell_10_done':     False,
    'buy_minus5_done':  False,
    'buy_minus10_done': False,
}


def _headers(extra: dict | None = None):
    return {
        'apikey':        _KEY,
        'Authorization': f'Bearer {_KEY}',
        'Content-Type':  'application/json',
        **(extra or {}),
    }


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _pg_code(r) -> str:
    try:
        return (r.json() or {}).get('code', '')
    except Exception:
        return ''


# 마이그레이션 20260917000001 적용 전이면 user_id 컬럼(42703)이나
# (user_id, stock_code) 유니크 제약(42P10)이 없다. 그때는 예전 방식으로 동작한다.
_PRE_MIGRATION_CODES = ('42703', '42P10', 'PGRST204')


# ── 포지션 상태 ────────────────────────────────────────────────────────────────
def get_position(stock_code: str, user_id: str | None = None) -> dict:
    """사용자별 포지션 플래그. 조회 실패 시 예외 — 상태를 모르면 물타기를 하면 안 된다."""
    filters = [f"stock_code=eq.{stock_code}"]
    if user_id:
        filters.append(f"user_id=eq.{user_id}")
    r = requests.get(
        f"{_URL}/rest/v1/trading_positions?{'&'.join(filters)}",
        headers=_headers(), timeout=_TIMEOUT,
    )
    if r.status_code == 400 and _pg_code(r) in _PRE_MIGRATION_CODES:
        print("⚠️  trading_positions.user_id 없음 — 마이그레이션 적용 전, 종목 단위로 조회")
        r = requests.get(
            f"{_URL}/rest/v1/trading_positions?stock_code=eq.{stock_code}",
            headers=_headers(), timeout=_TIMEOUT,
        )
        r.raise_for_status()
        rows = r.json()
        return rows[0] if rows else {'stock_code': stock_code, **_DEFAULT_FLAGS}
    r.raise_for_status()
    rows = r.json()

    # user_id 가 없던 시절에 저장된 행 — 마이그레이션 직후 기존 보유분의 플래그를 잃지 않도록
    if not rows and user_id:
        r = requests.get(
            f"{_URL}/rest/v1/trading_positions?stock_code=eq.{stock_code}&user_id=is.null",
            headers=_headers(), timeout=_TIMEOUT,
        )
        r.raise_for_status()
        rows = r.json()

    if rows:
        return rows[0]
    return {'stock_code': stock_code, 'user_id': user_id, **_DEFAULT_FLAGS}


def upsert_position(stock_code: str, user_id: str | None = None, **fields):
    body = {'stock_code': stock_code, 'user_id': user_id, 'updated_at': _now_iso(), **fields}
    prefer = _headers({'Prefer': 'resolution=merge-duplicates,return=representation'})
    r = requests.post(
        f"{_URL}/rest/v1/trading_positions?on_conflict=user_id,stock_code",
        headers=prefer, json=body, timeout=_TIMEOUT,
    )
    if r.status_code == 400 and _pg_code(r) in _PRE_MIGRATION_CODES:
        print("⚠️  (user_id, stock_code) 제약 없음 — 마이그레이션 적용 전, 종목 단위로 저장")
        body.pop('user_id', None)
        r = requests.post(
            f"{_URL}/rest/v1/trading_positions",
            headers=prefer, json=body, timeout=_TIMEOUT,
        )
    if not r.ok:
        # 저장 실패를 삼키면 다음 실행에서 같은 물타기를 또 한다
        print(f"❌ 포지션 저장 실패 ({stock_code}): {r.status_code} {r.text[:200]}")
    r.raise_for_status()
    return r.json()


def reset_position(stock_code: str, stock_name: str = '', user_id: str | None = None):
    return upsert_position(stock_code, user_id, stock_name=stock_name, **_DEFAULT_FLAGS)


# ── 거래 로그 ─────────────────────────────────────────────────────────────────
def log_trade(stock_code, stock_name, action, price, shares, amount, reason, user_id: str | None = None):
    payload: dict = {
        'stock_code': stock_code,
        'stock_name': stock_name,
        'action':     action,
        'price':      price,
        'shares':     shares,
        'amount':     amount,
        'reason':     reason,
        'created_at': _now_iso(),
    }
    if user_id:
        payload['user_id'] = user_id

    r = requests.post(
        f"{_URL}/rest/v1/trading_logs",
        headers=_headers({'Prefer': 'return=representation'}),
        json=payload, timeout=_TIMEOUT,
    )
    if not r.ok:
        # 일일 한도 집계가 이 로그에 의존하므로 실패는 반드시 드러낸다
        print(f"❌ 거래 로그 저장 실패 ({stock_code}): {r.status_code} {r.text[:200]}")
    r.raise_for_status()
    return r.json()


def get_today_buy_sum(user_id: str) -> int | None:
    """오늘(KST 00:00 이후) 이 사용자의 BUY 금액 합계. 조회 실패 시 None.

    None 을 0 으로 바꿔 돌려주면 한도가 무력화되므로 호출부가 매수를 보류해야 한다.
    """
    if not user_id:
        return 0
    kst_midnight = datetime.now(_KST).replace(hour=0, minute=0, second=0, microsecond=0)
    since = kst_midnight.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    try:
        r = requests.get(
            f"{_URL}/rest/v1/trading_logs"
            f"?select=amount&user_id=eq.{user_id}&action=eq.BUY&created_at=gte.{since}",
            headers=_headers(), timeout=_TIMEOUT,
        )
        if not r.ok:
            print(f"⚠️  오늘 매수 합계 조회 실패: {r.status_code} {r.text[:200]}")
            return None
        return sum(int(x.get('amount') or 0) for x in r.json())
    except Exception as e:
        print(f"⚠️  오늘 매수 합계 조회 오류: {e}")
        return None
