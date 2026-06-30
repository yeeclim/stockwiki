"""
복합 조건 매수 전략 — 점수제 (Score-based)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ 진입 조건  —  11점 만점, 6점 이상 매수 ]
  필수(+2) 현재가 < 60일 이평선           ← 미달 시 즉시 종료
  +2       골든크로스  (MA5 > MA20 크로스 발생)
           or +1  MA5 > MA20 (크로스 미발생, 유지 중)
  +1       저 PER  (0 < PER < 15)
  +1       저 PBR  (0 < PBR < 1.5)
  +1       거래량 충분  (≥ 100,000주)
  +1       부채비율 < 200%
  +1       유동비율 > 100%
  +1       현금비율 > 20%
  +1       이자보상배율 ≥ 400%

[ 추가매수 ]
  -5%  → 예수금  5% 추가매수
  -10% → 예수금 10% 추가매수

[ 매도 ]
  사용자 직접 판단 (자동 매도 미적용)
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
    max_score = 11
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
        log.append(f"  ❌ [+0] MA5({ma5 or 0:,.0f}) < MA20 — 하락 추세")

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

        ic = ratios.get('interest_coverage')
        if ic is not None:
            if ic >= 400:
                score += 1
                log.append(f"  ✅ [+1] 이자보상배율 {ic:.0f}% (기준 ≥ 400%)")
            else:
                log.append(f"  ❌ [+0] 이자보상배율 {ic:.0f}% — 낮음")
        else:
            log.append(f"  ⚠️  [+0] 이자보상배율 데이터 없음")
    else:
        log.append(f"  ⚠️  [+0] 재무비율 조회 실패 (부채·유동·현금·이자보상 4점 미반영)")

    return score, max_score, log


# ── 메인 전략 실행 ─────────────────────────────────────────────────────────────
def run(api, stock_code: str, stock_name: str, user_cfg: dict | None = None):
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

    prdy_ctrt  = fund.get('prdy_ctrt', 0.0)
    open_price = fund.get('open', 0)
    prdy_clpr  = fund.get('prdy_clpr', 0)
    if not prdy_clpr and prdy_ctrt and price:
        prdy_clpr = round(price / (1 + prdy_ctrt / 100))
    gap_pct = (open_price - prdy_clpr) / prdy_clpr * 100 if prdy_clpr else 0.0
    daily_drop = prdy_ctrt
    ma5, ma20 = ma_data.get('ma5'), ma_data.get('ma20')

    state = db.get_position(stock_code)
    user_id = None
    if user_cfg:
        user_id = user_cfg.get('user_id')

    # ── 포지션 없음 → 복합 진입 조건 평가 ───────────────────────────────────
    if shares == 0:
        ratios = api.get_financial_ratios(stock_code)
        score, max_score, log_lines = _score_entry(fund, ma_data, ratios)

        if score < BUY_THRESHOLD:
            print(f"보유수량   : {shares:>10,}주")
            print(f"예수금     : {cash:>10,}원")
            print(f"⏸  {score}/{max_score}점 미달 → 대기")
            return

        # 매수 확정 시에만 상세 출력
        print(f"현재가     : {price:>10,}원")
        print(f"전일 대비  : {prdy_ctrt:>+10.2f}%  (전일종가 {prdy_clpr:,}원)")
        print(f"시가       : {open_price:>10,}원  (갭 {gap_pct:+.2f}%)")
        if ma60:
            print(f"60일 MA    : {ma60:>10,.0f}원")
        if ma5 and ma20:
            cross_tag = ' 🔺골든크로스' if ma_data.get('golden_cross') else ''
            print(f"MA5/MA20   : {ma5:>10,.0f} / {ma20:,.0f}원{cross_tag}")
        print(f"PER / PBR  : {fund['per']:>9.1f} / {fund['pbr']:.2f}")
        print(f"거래량     : {fund['volume']:>10,}주")
        print(f"보유수량   : {shares:>10,}주  (평단가 {avg_price:,.0f}원)")
        print(f"예수금     : {cash:>10,}원")
        print(f"\n[ 진입 조건 점수 ]")
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

            orig_buy = int(cash * 0.25)
            # per-user cap (daily_max_buy) preferred; otherwise global cap
            user_cap = None
            if user_cfg:
                try:
                    dm = user_cfg.get('daily_max_buy')
                    if dm is not None:
                        user_cap = int(dm)
                except Exception:
                    user_cap = None

            GLOBAL_MAX_BUY = 500_000
            cap = user_cap if user_cap and user_cap > 0 else GLOBAL_MAX_BUY

            # Respect today's already bought sum if available
            if user_id:
                bought_today = db.get_today_buy_sum(user_id)
                remaining = cap - bought_today if cap else cap
                if remaining <= 0:
                    print(f"\n⏸  오늘 이미 일일 최대 매수금액({cap:,}원)을 소진했습니다. 매수 취소")
                    return
            else:
                remaining = cap

            buy_amount = orig_buy if orig_buy <= remaining else remaining
            if orig_buy > remaining:
                print(f"\n✅ 진입 확정 → 예수금 25% = {orig_buy:,}원 → 최대 {remaining:,}원 제한, {buy_amount:,}원 매수")
            else:
                print(f"\n✅ 진입 확정 → 예수금 25% = {buy_amount:,}원 매수")

            result = api.buy(stock_code, buy_amount)
            if result:
                db.reset_position(stock_code, stock_name)
                db.log_trade(stock_code, stock_name, 'BUY',
                             result['price'], result['shares'], result['amount'],
                             f'복합조건 {score}/{max_score}점 진입', user_id)
        else:
            print(f"\n⏸  조건 미달 ({score}점 < {BUY_THRESHOLD}점) → 대기")
        return

    # ── 포지션 있음 → 수익률 모니터링 (매도는 사용자 직접 판단)
    chg = (price - avg_price) / avg_price * 100
    print(f"보유수량   : {shares:>10,}주  (평단가 {avg_price:,.0f}원)")
    print(f"예수금     : {cash:>10,}원")
    print(f"수익률     : {chg:>+10.2f}%  📌 매도는 사용자 직접 판단")

    # ── 당일 급락 안전장치 ────────────────────────────────────────────────────
    DAILY_DROP_LIMIT = -5.0
    if prdy_ctrt <= DAILY_DROP_LIMIT:
        print(f"⛔ 당일 급락 {prdy_ctrt:.2f}% → 추가매수 금지")
        return

    # ── 추가매수 (물타기) ─────────────────────────────────────────────────────
    if chg <= -10 and not state.get('buy_minus10_done'):
        buy_amount = int(cash * 0.10)
        # apply per-user daily cap if available
        user_cap = None
        try:
            if user_cfg:
                dm = user_cfg.get('daily_max_buy')
                if dm is not None:
                    user_cap = int(dm)
        except Exception:
            user_cap = None
        GLOBAL_MAX_BUY = 500_000
        cap = user_cap if user_cap and user_cap > 0 else GLOBAL_MAX_BUY
        if user_id:
            bought_today = db.get_today_buy_sum(user_id)
            remaining = cap - bought_today if cap else cap
            if remaining <= 0:
                print(f"\n⏸  오늘 이미 일일 최대 매수금액({cap:,}원)을 소진했습니다. 추가매수 취소")
                return
            buy_amount = buy_amount if buy_amount <= remaining else remaining

        print(f"\n✅ -10% 도달 → 예수금 10% ({buy_amount:,}원) 추가매수")
        result = api.buy(stock_code, buy_amount)
        if result:
            db.upsert_position(stock_code, buy_minus10_done=True, user_id=user_id)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         '-10% 물타기 10%', user_id)

    elif chg <= -5 and not state.get('buy_minus5_done'):
        buy_amount = int(cash * 0.05)
        # apply per-user daily cap if available
        user_cap = None
        try:
            if user_cfg:
                dm = user_cfg.get('daily_max_buy')
                if dm is not None:
                    user_cap = int(dm)
        except Exception:
            user_cap = None
        GLOBAL_MAX_BUY = 500_000
        cap = user_cap if user_cap and user_cap > 0 else GLOBAL_MAX_BUY
        if user_id:
            bought_today = db.get_today_buy_sum(user_id)
            remaining = cap - bought_today if cap else cap
            if remaining <= 0:
                print(f"\n⏸  오늘 이미 일일 최대 매수금액({cap:,}원)을 소진했습니다. 추가매수 취소")
                return
            buy_amount = buy_amount if buy_amount <= remaining else remaining

        print(f"\n✅ -5% 도달 → 예수금 5% ({buy_amount:,}원) 추가매수")
        result = api.buy(stock_code, buy_amount)
        if result:
            db.upsert_position(stock_code, buy_minus5_done=True, user_id=user_id)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         '-5% 물타기 5%', user_id)

    else:
        print(f"⏸  추가매수 조건 미달 (수익률 {chg:+.2f}%) → 대기")
