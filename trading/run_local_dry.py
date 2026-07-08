#!/usr/bin/env python3
"""Local dry-run runner for strategy with FakeApi to simulate buy (no external calls)."""
import sys

# Ensure current directory (script dir) is in sys.path so `import strategy` works
import os
sys.path.insert(0, os.path.dirname(__file__))

import strategy

class FakeApi:
    def auth(self):
        print("[FakeApi] auth ok")

    def get_fundamentals(self, code: str) -> dict:
        # price, PER, PBR, volume, prdy_ctrt, open, prdy_clpr
        return {
            'price': 5000,
            'per': 10.0,
            'pbr': 1.0,
            'volume': 200_000,
            'prdy_ctrt': 1.0,
            'open': 5000,
            'prdy_clpr': 4950,
        }

    def get_ma_data(self, code: str) -> dict:
        return {
            'ma60': 6000,
            'ma5': 5100,
            'ma20': 5000,
            'golden_cross': True,
            'above_ma20': True,
        }

    def get_holdings(self, code: str) -> dict:
        return {'shares': 0, 'avg_price': 0}

    def get_cash(self) -> int:
        # Set cash high enough to trigger cap (25% of 3,000,000 = 750,000 > 500,000 cap)
        return 3_000_000

    def get_financial_ratios(self, code: str) -> dict:
        return {'부채비율': 100, '유동비율': 150, '현금비율': 30}

    def get_price(self, code: str) -> int:
        return 5000

    def buy(self, code: str, amount: int) -> dict | None:
        price = self.get_price(code)
        shares = amount // price
        if shares <= 0:
            print(f"⚠️ [FakeApi] buy not possible: {amount:,}원 / 현재가 {price:,}원")
            return None
        print(f"[FakeApi] BUY simulated: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}

    def sell(self, code: str, shares: int) -> dict | None:
        price = self.get_price(code)
        print(f"[FakeApi] SELL simulated: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}


if __name__ == '__main__':
    api = FakeApi()
    api.auth()
    # Monkeypatch `strategy`'s `db` to avoid Supabase network calls during local dry-run
    import types
    fake_db = types.SimpleNamespace()
    fake_db.get_position = lambda stock_code: {
        'stock_code': stock_code,
        'sell_5_done': False,
        'sell_10_done': False,
        'buy_minus5_done': False,
        'buy_minus10_done': False,
    }
    fake_db.upsert_position = lambda stock_code, **fields: {}
    fake_db.reset_position = lambda stock_code, stock_name='': {}
    fake_db.log_trade = lambda *args, **kwargs: {}
    fake_db.get_today_buy_sum = lambda user_id: 0
    strategy.db = fake_db
    # pass a sample user_cfg with daily_max_buy for testing
    strategy.run(api, '096350', '대창솔루션', {'user_id': 'localtest', 'daily_max_buy': 500000})
