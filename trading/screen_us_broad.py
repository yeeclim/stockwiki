"""
미국 주식 광역 스캔 — 전체 NASDAQ/NYSE/AMEX 보통주 스캔으로 us_screening_results 갱신
GitHub Actions 매일 실행. 국내 screen_broad.py와 동일하게 strategy._score_entry를
그대로 재사용해 "동일 조건"으로 채점한다 (10점 만점, 6점 이상 통과).

흐름:
  1. NASDAQ/NYSE/AMEX 전체 상장 보통주 코드+이름 수집 (ETF·워런트·우선주 제외)
  2. Yahoo Finance 배치 시세(가격/거래량/시총/PER/PBR) 조회 → 가격·거래량·시총 기초 필터
  3. 1차 통과 종목만 MA5/20/60 조회 → strategy._score_entry로 예비 점수 (재무비율 제외)
  4. 예비 점수 4점 이상 종목 중 상위 150개만 재무비율(부채비율·유동비율) 조회 → 최종 점수
  5. 최종 점수 6점 이상 종목을 us_screening_results 테이블에 upsert
     단, 결과가 0개이면 기존 candidates를 보존(삭제하지 않음)
"""
import os
import time
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone

import us_market_data as us
from strategy import _score_entry

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
_SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

MAX_WORKERS   = 8
CALL_DELAY    = 0.1
PRE_THRESHOLD = 5    # 국내 screen_broad.py와 동일
MIN_THRESHOLD = 6    # BUY_THRESHOLD (strategy.py와 동일)
TOP_N         = 60
STALE_DAYS    = 3    # 이보다 오래 갱신 안 된 결과는 정리 (그날 top-N 밖으로 밀려 방치된 종목)

MIN_PRICE          = 1
MAX_PRICE          = 5000
MIN_VOLUME         = 50_000
MIN_MARKET_CAP_USD = 200_000_000  # _score_entry의 4천억원 게이트보다 낙낙하게 — 최종 컷은 _score_entry가 담당


# ── 1차 필터: 배치 시세로 가격/거래량/시총 기초 필터 ────────────────────────

def _stage1_prefilter(stocks: list[dict], usd_krw: float) -> list[dict]:
    symbols = [s['code'] for s in stocks]
    quotes = us.get_quotes_batch(symbols)
    print(f"📊 배치 시세 조회: {len(quotes)}/{len(symbols)}종목 응답")

    survivors = []
    for s in stocks:
        q = quotes.get(s['code'])
        if not q:
            continue
        price      = q.get('regularMarketPrice', 0) or 0
        volume     = q.get('regularMarketVolume', 0) or 0
        market_cap = q.get('marketCap', 0) or 0

        if price < MIN_PRICE or price > MAX_PRICE:
            continue
        if volume < MIN_VOLUME:
            continue
        if market_cap < MIN_MARKET_CAP_USD:
            continue

        fund = {
            'price':      price,
            'volume':     volume,
            'per':        q.get('trailingPE') or 0,
            'pbr':        q.get('priceToBook') or 0,
            'market_cap': market_cap * usd_krw / 100_000_000,  # 억원 환산 — _score_entry 게이트 재사용용
        }
        survivors.append({
            **s,
            'name': q.get('shortName') or s['name'],
            'fund': fund,
            'market_cap_usd': market_cap,
        })
    return survivors


# ── 2차: MA 조회 + 예비 점수(재무비율 제외) ─────────────────────────────────

def _stage2_score(stock: dict) -> dict | None:
    try:
        time.sleep(CALL_DELAY)
        ma_data = us.get_ma_data(stock['code'])
        if not ma_data:
            return None
        score, _, _ = _score_entry(stock['fund'], ma_data, ratios=None)
        return {**stock, 'ma': ma_data, 'score': score}
    except Exception:
        return None


# ── 3차: 재무비율 포함 최종 점수 ─────────────────────────────────────────────

def _stage3_score_with_ratios(stock: dict) -> dict:
    try:
        ratios = us.get_ratios(stock['code'])
        score, _, _ = _score_entry(stock['fund'], stock['ma'], ratios)
        return {**stock, 'score': score, 'ratios': ratios}
    except Exception:
        return stock


# ── Supabase 저장 ────────────────────────────────────────────────────────────

def _upsert_results(candidates: list[dict]):
    if not candidates:
        print("⚠️  후보 종목 없음 — 기존 us_screening_results 보존 (삭제 생략)")
        return
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print("⚠️  Supabase 환경변수 없음 — 저장 생략")
        return

    now = datetime.now(timezone.utc).isoformat()
    rows = [
        {
            'stock_code':     c['code'],
            'stock_name':     c['name'],
            'sector':         c.get('sector', ''),
            'score':          c['score'],
            'price':          c['fund']['price'],
            'market_cap_usd': c.get('market_cap_usd', 0),
            'pass':           c['score'] >= MIN_THRESHOLD,
            'screened_at':    now,
        }
        for c in candidates
    ]
    try:
        resp = requests.post(
            f"{_SUPABASE_URL}/rest/v1/us_screening_results",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
                'Content-Type':  'application/json',
                'Prefer':        'resolution=merge-duplicates',
            },
            json=rows,
            timeout=30,
        )
        if resp.ok:
            print(f"💾 us_screening_results {len(rows)}개 저장 완료")
            _prune_stale_rows()
        else:
            print(f"⚠️  저장 실패: {resp.status_code} {resp.text[:200]}")
    except Exception as e:
        print(f"⚠️  저장 오류: {e}")


# 그날 top-N 밖으로 밀려 갱신되지 않는 종목이 pass=true 상태로 영원히 남는 것을 방지
def _prune_stale_rows():
    # isoformat()의 '+00:00' 타임존 표기가 URL 쿼리에서 '+'가 공백으로 깨져
    # PostgREST가 파싱 실패하므로 'Z' 표기로 치환
    cutoff = (datetime.now(timezone.utc) - timedelta(days=STALE_DAYS)).isoformat().replace('+00:00', 'Z')
    try:
        resp = requests.delete(
            f"{_SUPABASE_URL}/rest/v1/us_screening_results?screened_at=lt.{cutoff}",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
            },
            timeout=30,
        )
        if resp.ok:
            print(f"🗑️  {STALE_DAYS}일 초과 미갱신 결과 정리 완료")
        else:
            print(f"⚠️  오래된 결과 정리 실패: {resp.status_code} {resp.text[:200]}")
    except Exception as e:
        print(f"⚠️  오래된 결과 정리 오류: {e}")


# ── 메인 ─────────────────────────────────────────────────────────────────────

def main():
    print("🔍 미국 전체 NASDAQ/NYSE/AMEX 광역 스캔 시작")

    usd_krw = us.get_usd_krw_rate()
    print(f"💱 USD/KRW: {usd_krw:.2f}")

    all_stocks = us.fetch_universe()
    print(f"📋 전체 종목: {len(all_stocks)}개")
    if not all_stocks:
        print("❌ 종목 수집 실패 — 종료")
        return

    stage1 = _stage1_prefilter(all_stocks, usd_krw)
    print(f"📋 1차 필터 통과: {len(stage1)}개")
    if not stage1:
        print("❌ 1차 필터 통과 종목 없음 — 종료")
        return

    stage2 = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = {ex.submit(_stage2_score, s): s for s in stage1}
        done = 0
        for fut in as_completed(futures):
            done += 1
            if done % 300 == 0:
                print(f"  MA 조회 진행: {done}/{len(stage1)}")
            result = fut.result()
            if result and result['score'] >= PRE_THRESHOLD:
                stage2.append(result)

    stage2.sort(key=lambda x: x['score'], reverse=True)
    print(f"📊 예비 통과 ({PRE_THRESHOLD}점 이상): {len(stage2)}개")

    final_results = []
    for stock in stage2[:150]:
        scored = _stage3_score_with_ratios(stock)
        if scored['score'] >= MIN_THRESHOLD:
            final_results.append(scored)
        time.sleep(0.15)

    final_results.sort(key=lambda x: x['score'], reverse=True)
    top = final_results[:TOP_N]

    print(f"\n{'=' * 55}")
    print(f"  🏆 미국 광역 스캔 결과 — 상위 {len(top)}종목 ({MIN_THRESHOLD}점 이상)")
    print(f"{'=' * 55}")
    for r in top[:20]:
        print(f"  [{r['score']}/10점] {r['name']}({r['code']})  ${r['fund']['price']:,.2f}")

    _upsert_results(top)


if __name__ == "__main__":
    main()
