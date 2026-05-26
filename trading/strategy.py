"""
분할매수/분할매도 전략
- 진입: 현재가 < 60일 이평선 → 예수금 25% 매수
- +5%  → 보유량 5% 매도
- +10% → 보유량 10% 매도
- -5%  → 예수금 5% 추가매수
- -10% → 예수금 10% 추가매수
"""
import database as db


def run(api, stock_code: str, stock_name: str):
    sep = "=" * 55
    print(f"\n{sep}")
    print(f"  {stock_name} ({stock_code})")
    print(sep)

    # ── 데이터 수집 ────────────────────────────────────────────────────────────
    price = api.get_price(stock_code)
    print(f"현재가     : {price:>10,}원")

    ma60 = api.get_ma60(stock_code)
    if ma60 is None:
        print("❌ 60일 이평선 계산 불가 → 종료")
        return
    print(f"60일 MA    : {ma60:>10,.0f}원")

    h = api.get_holdings(stock_code)
    shares    = h['shares']
    avg_price = h['avg_price']
    print(f"보유수량   : {shares:>10,}주  (평단가 {avg_price:,.0f}원)")

    cash = api.get_cash()
    print(f"예수금     : {cash:>10,}원")

    state = db.get_position(stock_code)

    # ── 포지션 없음: 진입 조건 체크 ────────────────────────────────────────────
    if shares == 0:
        if price < ma60:
            buy_amount = int(cash * 0.25)
            print(f"\n✅ 진입 (현재가 {price:,} < MA60 {ma60:,.0f})")
            print(f"   예수금 25% = {buy_amount:,}원 매수")
            result = api.buy(stock_code, buy_amount)
            if result:
                db.reset_position(stock_code, stock_name)
                db.log_trade(stock_code, stock_name, 'BUY',
                             result['price'], result['shares'], result['amount'],
                             '60일 이평선 아래 첫 진입 25%')
        else:
            print(f"\n⏸  대기 (현재가 {price:,} ≥ MA60 {ma60:,.0f})")
        return

    # ── 포지션 있음: 수익률 기준 행동 ──────────────────────────────────────────
    chg = (price - avg_price) / avg_price * 100
    print(f"수익률     : {chg:>+10.2f}%")
    print()

    acted = False

    # +10% 매도 (이미 실행했으면 skip)
    if chg >= 10 and not state.get('sell_10_done'):
        qty = max(1, int(shares * 0.10))
        print(f"✅ +10% 도달 → {qty}주 매도 (보유량 10%)")
        result = api.sell(stock_code, qty)
        if result:
            db.upsert_position(stock_code, sell_10_done=True)
            db.log_trade(stock_code, stock_name, 'SELL',
                         result['price'], result['shares'], result['amount'],
                         '+10% 익절 10% 매도')
        acted = True

    # +5% 매도
    elif chg >= 5 and not state.get('sell_5_done'):
        qty = max(1, int(shares * 0.05))
        print(f"✅ +5% 도달 → {qty}주 매도 (보유량 5%)")
        result = api.sell(stock_code, qty)
        if result:
            db.upsert_position(stock_code, sell_5_done=True)
            db.log_trade(stock_code, stock_name, 'SELL',
                         result['price'], result['shares'], result['amount'],
                         '+5% 익절 5% 매도')
        acted = True

    # -10% 추가매수
    elif chg <= -10 and not state.get('buy_minus10_done'):
        buy_amount = int(cash * 0.10)
        print(f"✅ -10% 도달 → 예수금 10% ({buy_amount:,}원) 추가매수")
        result = api.buy(stock_code, buy_amount)
        if result:
            db.upsert_position(stock_code, buy_minus10_done=True)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         '-10% 물타기 10%')
        acted = True

    # -5% 추가매수
    elif chg <= -5 and not state.get('buy_minus5_done'):
        buy_amount = int(cash * 0.05)
        print(f"✅ -5% 도달 → 예수금 5% ({buy_amount:,}원) 추가매수")
        result = api.buy(stock_code, buy_amount)
        if result:
            db.upsert_position(stock_code, buy_minus5_done=True)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         '-5% 물타기 5%')
        acted = True

    if not acted:
        print("⏸  조건 미달 또는 이미 실행됨 → 대기")
