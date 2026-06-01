"""
복합 조건 매수 전략 — 점수제 (Score-based)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ 진입 조건  —  10점 만점, 6점 이상 매수 ]
  필수(+2) 현재가 < 60일 이평선           ← 미달 시 즉시 종료
  +2       골든크로스  (MA5 > MA20 크로스 발생)
           or +1  MA5 > MA20 (크로스 미발생, 유지 중)
  +1       저 PER  (0 < PER < 15)
  +1       저 PBR  (0 < PBR < 1.5)
  +1       거래량 충분  (≥ 100,000주)
  +1       부채비율 < 200%
  +1       유동비율 > 100%
  +1       현금비율 > 20%

[ 분할매도 / 추가매수 — 기존 동일 ]
  +5%  → 보유량  5% 매도
  +10% → 보유량 10% 매도
  -5%  → 예수금  5% 추가매수
  -10% → 예수금 10% 추가매수
"""
import database as db

BUY_THRESHOLD = 6   # 10점 만점 중 최소 매수 점수


# ── 진입 점수 계산 ─────────────────────────────────────────────────────────────
def _score_entry(fund: dict, ma_data: dict, ratios):
    """
    fund    : api.get_fundamentals() 결과
    ma_data : api.get_ma_data() 결과
    ratios  : api.get_financial_ratios() 결과 (None 허용)
    반환    : (score, max_score, log_lines)
    """
    score     = 0
    max_score = 10
    log       = []
    price     = fund['price']

    # ❶ 현재가 < 60일 이평선  [필수, +2점] ─────────────────────────────────────
    ma60 = ma_data.get('ma60')
    if ma60 is None:
        log.append("  ⛔ 60일 이평선 데이터 부족 → 진입 불가")
        return 0, max_score, log

    if price < ma60:
        score += 2
        log.append(f"  ✅ [+2] 현재가({price:,}) < MA60({ma60:,.0f})")
    else:
        log.append(f"  ❌ [+0] 현재가({price:,}) ≥ MA60({ma60:,.0f}) — 필수 조건 미달")
        return score, max_score, log

    # ❷ 골든크로스 / MA5 > MA20  [+2 or +1점] ─────────────────────────────────
    ma5  = ma_data.get('ma5')
    ma20 = ma_data.get('ma20')
    if ma_data.get('golden_cross'):
        score += 2
        log.append(f"  ✅ [+2] 골든크로스 발생 (MA5 {ma5:,.0f} ↑ MA20 {ma20:,.0f})")
    elif ma_data.get('above_ma20'):
        score += 1
        log.append(f"  🔶 [+1] MA5({ma5:,.0f}) > MA20({ma20:,.0f}) 유지 중")
    else:
        log.append(f"  ❌ [+0] MA5({ma5:,.0f if ma5 else 0}) < MA20 — 하락 추세")

    # ❸ 저 PER  [+1점] ──────────────────────────────────────────────────────────
    per = fund.get('per', 0)
    if 0 < per < 15:
        score += 1
        log.append(f"  ✅ [+1] 저PER {per:.1f} (기준 < 15)")
    elif per == 0:
        log.append(f"  ⚠️  [+0] PER 데이터 없음")
    else:
        log.append(f"  ❌ [+0] PER {per:.1f} ≥ 15")

    # ❹ 저 PBR  [+1점] ──────────────────────────────────────────────────────────
    pbr = fund.get('pbr', 0)
    if 0 < pbr < 1.5:
        score += 1
        log.append(f"  ✅ [+1] 저PBR {pbr:.2f} (기준 < 1.5)")
    elif pbr == 0:
        log.append(f"  ⚠️  [+0] PBR 데이터 없음")
    else:
        log.append(f"  ❌ [+0] PBR {pbr:.2f} ≥ 1.5")

    # ❺ 거래량  [+1점] ─────────────────────────────────────────────────────────
    volume = fund.get('volume', 0)
    if volume >= 100_000:
        score += 1
        log.append(f"  ✅ [+1] 거래량 {volume:,}주 (기준 ≥ 100,000)")
    else:
        log.append(f"  ❌ [+0] 거래량 부족 {volume:,}주")

    # ❻ 재무비율: 부채비율 · 유동비율 · 현금비율  [각 +1점] ───────────────────
    if ratios:
        debt    = ratios.get('debt_ratio')
        current = ratios.get('current_ratio')
        cash_r  = ratios.get('cash_ratio')

        if debt is not None:
            if debt < 200:
                score += 1
                log.append(f"  ✅ [+1] 부채비율 {debt:.0f}% (기준 < 200%)")
            else:
                log.append(f"  ❌ [+0] 부채비율 {debt:.0f}% — 과다")
        else:
            log.append(f"  ⚠️  [+0] 부채비율 데이터 없음")

        if current is not None:
            if current > 100:
                score += 1
                log.append(f"  ✅ [+1] 유동비율 {current:.0f}% (기준 > 100%)")
            else:
                log.append(f"  ❌ [+0] 유동비율 {current:.0f}% — 부족")
        else:
            log.append(f"  ⚠️  [+0] 유동비율 데이터 없음")

        if cash_r is not None:
            if cash_r > 20:
                score += 1
                log.append(f"  ✅ [+1] 현금비율 {cash_r:.0f}% (기준 > 20%)")
            else:
                log.append(f"  ❌ [+0] 현금비율 {cash_r:.0f}% — 낮음")
        else:
            log.append(f"  ⚠️  [+0] 현금비율 데이터 없음")
    else:
        log.append(f"  ⚠️  [+0] 재무비율 조회 실패 (부채·유동·현금 3점 미반영)")

    return score, max_score, log


# ── 메인 전략 실행 ─────────────────────────────────────────────────────────────
def run(api, stock_code: str, stock_name: str):
    sep = "=" * 55
    print(f"\n{sep}")
    print(f"  {stock_name} ({stock_code})")
    print(sep)

    # 데이터 수집 (중복 API 호출 최소화)
    fund    = api.get_fundamentals(stock_code)   # price, PER, PBR, volume
    price   = fund['price']
    ma_data = api.get_ma_data(stock_code)        # MA5/20/60/120 + 골든크로스
    ma60    = ma_data.get('ma60')

    h         = api.get_holdings(stock_code)
    shares    = h['shares']
    avg_price = h['avg_price']
    cash      = api.get_cash()

    # 기본 정보 출력
    prdy_ctrt  = fund.get('prdy_ctrt', 0.0)   # 전일 대비율
    open_price = fund.get('open', 0)            # 당일 시가
    prdy_clpr  = fund.get('prdy_clpr', 0)       # 전일 종가
    gap_pct    = (open_price - prdy_clpr) / prdy_clpr * 100 if prdy_clpr else 0.0

    print(f"현재가     : {price:>10,}원")
    print(f"전일 대비  : {prdy_ctrt:>+10.2f}%  (전일종가 {prdy_clpr:,}원)")
    print(f"시가       : {open_price:>10,}원  (갭 {gap_pct:+.2f}%)")
    if ma60:
        print(f"60일 MA    : {ma60:>10,.0f}원")
    ma5, ma20 = ma_data.get('ma5'), ma_data.get('ma20')
    if ma5 and ma20:
        cross_tag = ' 🔺골든크로스' if ma_data.get('golden_cross') else ''
        print(f"MA5/MA20   : {ma5:>10,.0f} / {ma20:,.0f}원{cross_tag}")
    print(f"PER / PBR  : {fund['per']:>9.1f} / {fund['pbr']:.2f}")
    print(f"거래량     : {fund['volume']:>10,}주")
    print(f"보유수량   : {shares:>10,}주  (평단가 {avg_price:,.0f}원)")
    print(f"예수금     : {cash:>10,}원")

    state = db.get_position(stock_code)

    # ── 포지션 없음 → 복합 진입 조건 평가 ───────────────────────────────────
    if shares == 0:
        ratios = api.get_financial_ratios(stock_code)

        print(f"\n[ 진입 조건 점수 ]")
        score, max_score, log_lines = _score_entry(fund, ma_data, ratios)
        for line in log_lines:
            print(line)

        bar = '█' * score + '░' * (max_score - score)
        print(f"\n  📊 [{bar}] {score}/{max_score}점  (매수 기준: {BUY_THRESHOLD}점 이상)")

        if score >= BUY_THRESHOLD:
            # 당일 급등 종목 고점 추격 매수 방지
            DAILY_SURGE_LIMIT = 5.0
            if daily_drop >= DAILY_SURGE_LIMIT:
                print(f"\n⛔ 당일 급등 +{daily_drop:.2f}% (기준 +{DAILY_SURGE_LIMIT}%) → 고점 추격 매수 금지")
                print("⏸  이미 많이 오른 종목 — 진입 보류")
                return

            buy_amount = int(cash * 0.25)
            print(f"\n✅ 진입 확정 → 예수금 25% = {buy_amount:,}원 매수")
            result = api.buy(stock_code, buy_amount)
            if result:
                db.reset_position(stock_code, stock_name)
                db.log_trade(stock_code, stock_name, 'BUY',
                             result['price'], result['shares'], result['amount'],
                             f'복합조건 {score}/{max_score}점 진입')
        else:
            print(f"\n⏸  조건 미달 ({score}점 < {BUY_THRESHOLD}점) → 대기")
        return

    # ── 포지션 있음 → 수익률 기준 분할매도 / 추가매수 ───────────────────────
    chg = (price - avg_price) / avg_price * 100
    print(f"수익률     : {chg:>+10.2f}%")

    # ── 당일 급락 안전장치 ────────────────────────────────────────────────────
    # 전일 대비 -5% 이상 하락 중이면 추가매수 금지 (악재·갭하락 대응)
    DAILY_DROP_LIMIT = -5.0
    daily_drop = prdy_ctrt  # 이미 계산된 전일 대비율
    if daily_drop <= DAILY_DROP_LIMIT:
        print(f"\n⛔ 당일 급락 {daily_drop:.2f}% (기준 {DAILY_DROP_LIMIT}%) → 추가매수 전면 금지")
        print("⏸  악재 가능성 — 매수 보류")
        return

    print()
    acted = False

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
