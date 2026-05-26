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
def log_trade(stock_code, stock_name, action, price, shares, amount, reason):
    r = requests.post(
        f"{_URL}/rest/v1/trading_logs",
        headers={**_headers(), 'Prefer': 'return=representation'},
        json={
            'stock_code': stock_code,
            'stock_name': stock_name,
            'action':     action,
            'price':      price,
            'shares':     shares,
            'amount':     amount,
            'reason':     reason,
            'created_at': datetime.now().isoformat(),
        },
    )
    return r.json()
