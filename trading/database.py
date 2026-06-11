"""
Supabase REST API 연동 (포지션 상태 + 거래 로그)
"""
import os
import requests
from datetime import datetime

_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').replace('\n', '').strip()

def _headers():
    return {
        'apikey':        _KEY,
        'Authorization': f'Bearer {_KEY}',
        'Content-Type':  'application/json',
    }

# ── 포지션 상태 ────────────────────────────────────────────────────────────────
def get_position(stock_code: str) -> dict:
    # If table has user_id column, callers may include user_id in query externally.
    r = requests.get(
        f"{_URL}/rest/v1/trading_positions?stock_code=eq.{stock_code}",
        headers=_headers(),
    )
    rows = r.json()
    if rows:
        return rows[0]
    return {
        'stock_code':       stock_code,
        'sell_5_done':      False,
        'sell_10_done':     False,
        'buy_minus5_done':  False,
        'buy_minus10_done': False,
    }

def upsert_position(stock_code: str, **fields):
    body = {
        'stock_code':  stock_code,
        'updated_at':  datetime.now().isoformat(),
        **fields,
    }
    r = requests.post(
        f"{_URL}/rest/v1/trading_positions",
        headers={**_headers(), 'Prefer': 'resolution=merge-duplicates,return=representation'},
        json=body,
    )
    return r.json()

def reset_position(stock_code: str, stock_name: str = ''):
    return upsert_position(
        stock_code,
        stock_name=stock_name,
        sell_5_done=False,
        sell_10_done=False,
        buy_minus5_done=False,
        buy_minus10_done=False,
    )

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
        'created_at': datetime.now().isoformat(),
    }
    if user_id:
        payload['user_id'] = user_id

    r = requests.post(
        f"{_URL}/rest/v1/trading_logs",
        headers={**_headers(), 'Prefer': 'return=representation'},
        json=payload,
    )
    return r.json()


def get_today_buy_sum(user_id: str) -> int:
    """Sum of BUY amounts for the given user for today (00:00 KST → now)."""
    if not user_id:
        return 0
    today = datetime.now().date().isoformat()
    try:
        r = requests.get(
            f"{_URL}/rest/v1/trading_logs?user_id=eq.{user_id}&action=eq.BUY&created_at=gte.{today}T00:00:00",
            headers=_headers(),
            timeout=10,
        )
        if not r.ok:
            return 0
        rows = r.json()
        total = sum(int(x.get('amount', 0) or 0) for x in rows)
        return total
    except Exception:
        return 0
