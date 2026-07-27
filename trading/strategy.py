"""
복합 조건 매수 전략 — 점수제 (Score-based)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ 진입 조건  —  13점 만점, 8점 이상 매수 ]
  필수(+1) 현재가 < 60일 이평선           ← 미달 시 즉시 종료
  필수(+1) MA5 > MA20 (단기 반등 확인)    ← 미달 시(하락 지속 중) 즉시 종료
           +1 추가  골든크로스 (오늘 교차 발생)
  +1       저 PER  (0 < PER < 15)
  +1       저 PBR  (0 < PBR < 1.5)
  +1       거래량 충분  (≥ 100,000주)
  +1       부채비율 < 200%
  +1       유동비율 > 100%
  +1       현금비율 > 20%
  +1       이자보상배율 ≥ 400%
  +1       RSI 과매도 반등 (RSI14가 최근 10일 내 30 밑으로 갔다가 30 위로 회복)
  +1       바닥 다지기 (최근 60일 저점 대비 8% 이내 + 최근 10일간 신저가 갱신 없음)
  +1       거래량 감소 추세 (최근 5일 평균 < 직전 20일 평균 — 투매 소진 정황)

  ※ MA5>MA20을 보너스가 아닌 필수 조건으로 둔 이유: 저PER·저PBR은 실제 저평가가
    아니라 급락 때문에 낮아진 값일 수 있고, 거래량도 패닉 매도로 커질 수 있어
    이 항목들만으로는 "싸 보이지만 계속 하락 중인 종목"을 걸러내지 못한다.
    단기 반등 신호가 없으면 나머지 점수가 높아도 매수하지 않는다.
    RSI 과매도 반등·바닥 다지기·거래량 감소 추세 3개 지표는 "얼마나 빠졌고
    얼마나 횡보했는지"를 직접 측정해 이 문제를 한 번 더 보강한다
    (trading/technical_indicators.py, 국내·미국 공통 재사용).

[ 뉴스 감성 게이트 ]
  진입 점수 통과(8점 이상) 후에도, 최근 뉴스 감성분석 결과가 "부정"이면 매수하지 않는다.
  (news_sentiment.get_sentiment 참고 — 뉴스 없음/분석 실패는 배제 사유로 보지 않음)

[ 추가매수 ]
  -5%  → 예수금  5% 추가매수
  -10% → 예수금 10% 추가매수

[ 매도 ]
  사용자 직접 판단 (자동 매도 미적용)
"""
import os
import json
import requests
import database as db
import news_sentiment

BUY_THRESHOLD = 8   # 13점 만점 중 최소 매수 점수 (기존 6/10 비율 유지, 바닥지표 3개 추가로 13점 만점)


def _ask_sell_timing(stock_name: str, stock_code: str, buy_price: int, fund: dict, ma_data: dict, score: int) -> str:
    """매수 직후 Claude에게 매도 타이밍 의견 요청"""
    key = os.environ.get('ANTHROPIC_API_KEY', '').strip()
    if not key:
        return '(ANTHROPIC_API_KEY 미설정)'
    try:
        ma60 = ma_data.get('ma60') or 0
        ma20 = ma_data.get('ma20') or 0
        prompt = (
            f"한국 주식 {stock_name}({stock_code})을 방금 {buy_price:,}원에 매수했습니다.\n"
            f"현재가: {buy_price:,}원 / MA60: {ma60:,.0f}원 / MA20: {ma20:,.0f}원\n"
            f"PER: {fund.get('per', 0):.1f} / PBR: {fund.get('pbr', 0):.2f} / 스크리닝 점수: {score}/13점\n\n"
            "기술적 분석 관점에서 매도 타이밍을 간략히 제안해주세요.\n"
            "아래 JSON 형식으로만 응답하세요:\n"
            '{"target": "목표 매도가 또는 조건 (20자 이내)", "stop": "손절 기준 (20자 이내)", "comment": "한 줄 근거 (40자 이내)"}'
        )
        resp = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers={
                'x-api-key':         key,
                'anthropic-version': '2023-06-01',
                'content-type':      'application/json',
            },
            json={
                'model':      'claude-haiku-4-5-20251001',
                'max_tokens': 150,
                'messages':   [{'role': 'user', 'content': prompt}],
            },
            timeout=15,
        )
        resp.raise_for_status()
        text = resp.json()['content'][0]['text'].strip()
        if '```' in text:
            text = text.split('```')[1].lstrip('json').strip()
        d = json.loads(text)
        return (
            f"🎯 목표매도: {d.get('target', '?')}  "
            f"🛑 손절기준: {d.get('stop', '?')}\n"
            f"   💬 {d.get('comment', '')}"
        )
    except Exception as e:
        return f'(분석 실패: {e})'


# ── 진입 점수 계산 ─────────────────────────────────────────────────────────────
def _score_entry(fund: dict, ma_data: dict, ratios):
    """
    fund    : api.get_fundamentals() 결과
    ma_data : api.get_ma_data() 결과
    ratios  : api.get_financial_ratios() 결과 (None 허용)
    반환    : (score, max_score, log_lines)
    """
    score     = 0
    max_score = 13
    log       = []
    price     = fund['price']

    # ❶ 시가총액 필터  [필수, 4천억 미만 제외] ──────────────────────────────────
    market_cap = fund.get('market_cap', 0)
    if market_cap and market_cap < 4000:
        log.append(f"  ⛔ 시총 {market_cap:,}억원 — 4천억 미만 제외")
        return 0, max_score, log

    # ❷ 현재가 < 60일 이평선  [필수, +1점] ─────────────────────────────────────
    ma60 = ma_data.get('ma60')
    if ma60 is None:
        log.append("  ⛔ 60일 이평선 데이터 부족 → 진입 불가")
        return 0, max_score, log

    if price < ma60:
        score += 1
        log.append(f"  ✅ [+1] 현재가({price:,}) < MA60({ma60:,.0f})")
    else:
        log.append(f"  ❌ [+0] 현재가({price:,}) ≥ MA60({ma60:,.0f}) — 필수 조건 미달")
        return score, max_score, log

    # ❷ MA5 > MA20  [필수, +1점] — 미달 시 "하락 지속 중"으로 보고 즉시 종료 ─────
    # 저PER·저PBR·거래량만으로는 급락 중인 종목과 진짜 저평가 종목을 구분 못 하므로,
    # 단기 반등(MA5>MA20)이 확인되지 않으면 나머지 항목 점수와 무관하게 탈락시킨다.
    ma5  = ma_data.get('ma5')
    ma20 = ma_data.get('ma20')
    if not (ma5 and ma20 and ma5 > ma20):
        log.append(f"  ❌ [+0] MA5({ma5 or 0:,.0f}) ≤ MA20({ma20 or 0:,.0f}) — 하락 지속 중, 필수 조건 미달")
        return score, max_score, log

    score += 1
    log.append(f"  ✅ [+1] MA5({ma5:,.0f}) > MA20({ma20:,.0f}) — 단기 반등 확인")

    if ma_data.get('golden_cross'):
        score += 1
        log.append(f"  ✅ [+1] 골든크로스 발생 (오늘 교차)")

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
        debt    = ratios.get('부채비율')
        current = ratios.get('유동비율')
        cash_r  = ratios.get('현금비율')

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

        ic = ratios.get('이자보상배율')
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

    # ❼ RSI 과매도 반등  [+1점] — "얼마나 빠졌는지"를 직접 측정 ──────────────────
    rsi = ma_data.get('rsi')
    if ma_data.get('rsi_rebound'):
        score += 1
        log.append(f"  ✅ [+1] RSI 과매도 반등 (현재 {rsi:.0f}, 최근 30 밑에서 회복)")
    elif rsi is not None:
        log.append(f"  ❌ [+0] RSI {rsi:.0f} — 과매도 반등 아님")
    else:
        log.append(f"  ⚠️  [+0] RSI 데이터 부족")

    # ❽ 바닥 다지기  [+1점] — 저점 근접 + 최근 신저가 갱신 없음 ─────────────────
    if ma_data.get('basing'):
        score += 1
        log.append(f"  ✅ [+1] 저점 근접 + 최근 신저가 갱신 없음 — 바닥 다지는 중")
    else:
        log.append(f"  ❌ [+0] 바닥 다지기 신호 없음")

    # ❾ 거래량 감소 추세  [+1점] — 투매(패닉 매도) 소진 신호 ────────────────────
    if ma_data.get('volume_declining'):
        score += 1
        log.append(f"  ✅ [+1] 거래량 감소 추세 — 매도세 소진 정황")
    else:
        log.append(f"  ❌ [+0] 거래량 감소 추세 아님")

    return score, max_score, log


# ── 메인 전략 실행 ─────────────────────────────────────────────────────────────
def run(api, stock_code: str, stock_name: str, user_cfg: dict | None = None):
    sep = "=" * 55

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
            return

        sentiment, sentiment_line = news_sentiment.get_sentiment(stock_code, stock_name)
        if sentiment == '부정':
            print(f"⏸  {stock_name}({stock_code}): 진입 조건 {score}점 통과했으나 "
                  f"뉴스 감성 부정적이라 매수 보류 — {sentiment_line}")
            return

        # 당일 급등 방지
        DAILY_SURGE_LIMIT = 5.0
        if daily_drop >= DAILY_SURGE_LIMIT:
            return

        orig_buy = int(cash * 0.25)
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

        if user_id:
            bought_today = db.get_today_buy_sum(user_id)
            remaining = cap - bought_today if cap else cap
            if remaining <= 0:
                return
        else:
            remaining = cap

        buy_amount = orig_buy if orig_buy <= remaining else remaining
        result = api.buy(stock_code, buy_amount)
        if result:
            # 매수 성공 시에만 상세 출력
            print(f"\n{sep}")
            print(f"  {stock_name} ({stock_code})")
            print(sep)
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
            print(f"예수금     : {cash:>10,}원")
            bar = '█' * score + '░' * (max_score - score)
            print(f"\n[ 진입 조건 점수 ]")
            for line in log_lines:
                print(line)
            print(f"\n  📊 [{bar}] {score}/{max_score}점")
            if orig_buy > remaining:
                print(f"\n✅ 진입 확정 → 예수금 25% = {orig_buy:,}원 → 최대 {remaining:,}원 제한, {buy_amount:,}원 매수")
            else:
                print(f"\n✅ 진입 확정 → 예수금 25% = {buy_amount:,}원 매수")
            db.reset_position(stock_code, stock_name)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         f'복합조건 {score}/{max_score}점 진입', user_id)
            sell_opinion = _ask_sell_timing(
                stock_name, stock_code, result['price'], fund, ma_data, score)
            print(f"\n[ AI 매도 타이밍 의견 ]\n  {sell_opinion}")

            # 게시판 매수 기록 등록
            try:
                import board_post
                from datetime import datetime
                import pytz
                date_str = datetime.now(pytz.timezone('Asia/Seoul')).strftime('%Y-%m-%d %H:%M')
                bp_title = f"[매수] {date_str} {stock_name}({stock_code}) {result['price']:,}원"
                bp_content = board_post.buy_content(
                    stock_name, stock_code,
                    result['price'], result['amount'], result['shares'],
                    score, max_score, log_lines, sell_opinion,
                    ratios or {},
                )
                board_post.post(bp_title, bp_content)
            except Exception:
                pass
        return

    # ── 포지션 있음 → 수익률 모니터링 (매도는 사용자 직접 판단)
    print(f"\n{sep}")
    print(f"  {stock_name} ({stock_code})")
    print(sep)
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

        result = api.buy(stock_code, buy_amount)
        if result:
            print(f"\n✅ -10% 도달 → 예수금 10% ({buy_amount:,}원) 추가매수")
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

        result = api.buy(stock_code, buy_amount)
        if result:
            print(f"\n✅ -5% 도달 → 예수금 5% ({buy_amount:,}원) 추가매수")
            db.upsert_position(stock_code, buy_minus5_done=True, user_id=user_id)
            db.log_trade(stock_code, stock_name, 'BUY',
                         result['price'], result['shares'], result['amount'],
                         '-5% 물타기 5%', user_id)

    else:
        print(f"⏸  추가매수 조건 미달 (수익률 {chg:+.2f}%) → 대기")
