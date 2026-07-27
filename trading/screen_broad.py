"""
광역 종목 스캔 — 전체 KOSPI/KOSDAQ 스캔으로 screening_candidates 자동 갱신
GitHub Actions 매주 월요일 07:00 KST 실행

흐름:
  1. FinanceDataReader → 전체 상장 종목 코드+이름 수집
  2. 코드 패턴 필터 (ETF·우선주 제외)
  3. KIS API 병렬 조회 (fundamentals + 가격/거래량 필터 + MA) → 예비 점수
  4. 예비 점수 4점 이상 종목만 FnGuide 재무비율 조회 → 최종 점수
  5. 최종 점수 4점 이상 종목을 screening_candidates 테이블에 upsert
     단, 결과가 0개이면 기존 candidates를 보존(삭제하지 않음)
"""
import os
import time
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

from kis_api import KISApi
from strategy import _score_entry

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
_SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

_api: KISApi | None = None

MAX_WORKERS   = 5    # 병렬 스레드 수
CALL_DELAY    = 0.15 # 스레드별 API 호출 간 최소 대기(초)
PRE_THRESHOLD = 6    # 예비 점수 이상이면 재무비율 조회 (13점 만점 중 재무비율 4점 제외한 예비 최대 9점 기준)
MIN_THRESHOLD = 8    # 최종 점수 이상이면 candidates에 등록 (strategy.BUY_THRESHOLD와 동일)
TOP_N         = 60   # candidates에 저장할 최대 종목 수


# ── 전체 종목 수집 ──────────────────────────────────────────────────────────────

def _fetch_all_stocks() -> list[dict]:
    """FinanceDataReader로 KOSPI/KOSDAQ 전체 종목 목록 수집"""
    try:
        import FinanceDataReader as fdr
    except ImportError:
        print("❌ FinanceDataReader 미설치 — pip install finance-datareader")
        return []

    all_stocks = []
    for market in ["KOSPI", "KOSDAQ"]:
        try:
            df = fdr.StockListing(market)
            count = 0
            for _, row in df.iterrows():
                code = str(row.get("Code", "")).strip()
                name = str(row.get("Name", "")).strip()
                if not code or not name:
                    continue
                # 6자리가 아닌 경우 제로패딩
                code = code.zfill(6)
                all_stocks.append({
                    "code":   code,
                    "name":   name,
                    "sector": market,
                })
                count += 1
            print(f"📋 {market}: {count}종목 수집")
        except Exception as e:
            print(f"⚠️  {market} 종목 조회 실패: {e}")
    return all_stocks


def _prefilter(stocks: list[dict]) -> list[dict]:
    """코드 패턴으로 ETF·우선주 등 비대상 제외"""
    filtered = []
    for s in stocks:
        code = s["code"]
        if len(code) != 6 or not code.isdigit():
            continue
        if code.startswith("1"):          # ETF 코드 대역 (10xxxx)
            continue
        if code.endswith(("5", "7")):     # 우선주 (삼성전자우 005935 등)
            continue
        filtered.append(s)
    return filtered


# ── 종목 점수 계산 ──────────────────────────────────────────────────────────────

def _score_stock(stock: dict) -> dict | None:
    """예비 점수 계산: fundamentals 조회 → 가격/거래량 필터 → MA 조회 → 점수"""
    global _api
    code = stock["code"]
    try:
        time.sleep(CALL_DELAY)
        fund = _api.get_fundamentals(code)

        # 가격·거래량 기초 필터 (KIS 실데이터 기준)
        price      = fund.get("price", 0)
        volume     = fund.get("volume", 0)
        market_cap = fund.get("market_cap", 0)
        if price < 1_000 or price > 800_000 or volume < 50_000:
            return None
        if market_cap and market_cap < 4_000:
            return None

        ma_data = _api.get_ma_data(code)
        score, _, _ = _score_entry(fund, ma_data, ratios=None)
        return {**stock, "score": score, "fund": fund, "ma": ma_data}
    except Exception:
        return None


def _score_with_ratios(stock: dict) -> dict:
    """재무비율 포함 최종 점수 계산"""
    global _api
    try:
        ratios = _api.get_financial_ratios(stock["code"])
        score, _, _ = _score_entry(stock["fund"], stock["ma"], ratios)
        return {**stock, "score": score, "ratios": ratios}
    except Exception:
        return stock


# ── Supabase 저장 ───────────────────────────────────────────────────────────────

def _upsert_candidates(candidates: list[dict]):
    """screening_candidates 테이블 갱신 (시스템 종목 교체)
    결과가 비어 있으면 기존 데이터를 보존하고 아무것도 하지 않는다.
    """
    if not candidates:
        print("⚠️  후보 종목 없음 — 기존 candidates 보존 (삭제 생략)")
        return

    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print("⚠️  Supabase 환경변수 없음 — 저장 생략")
        return

    headers = {
        "apikey":        _SUPABASE_KEY,
        "Authorization": f"Bearer {_SUPABASE_KEY}",
        "Content-Type":  "application/json",
    }

    # 1. 기존 시스템 종목 삭제 (functional unique index 충돌 방지)
    try:
        requests.delete(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates"
            "?source=eq.system&user_id=is.null",
            headers=headers,
            timeout=10,
        )
    except Exception as e:
        print(f"⚠️  기존 시스템 종목 삭제 실패: {e}")
        return

    # 2. 새 종목 삽입
    rows = [
        {
            "stock_code": c["code"],
            "stock_name": c["name"],
            "sector":     c.get("sector", ""),
            "is_active":  True,
            "source":     "system",
        }
        for c in candidates
    ]
    try:
        resp = requests.post(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates",
            headers={**headers, "Prefer": "return=minimal"},
            json=rows,
            timeout=30,
        )
        if resp.ok:
            print(f"✅ screening_candidates 갱신 완료 — {len(rows)}종목")
        else:
            print(f"⚠️  새 종목 저장 실패: {resp.status_code} {resp.text[:200]}")
    except Exception as e:
        print(f"⚠️  새 종목 저장 오류: {e}")


# ── 메인 ────────────────────────────────────────────────────────────────────────

def main():
    global _api

    print("🔍 전체 KOSPI/KOSDAQ 광역 스캔 시작")

    _api = KISApi()
    try:
        _api.auth()
        print("✅ KIS 토큰 발급 완료")
    except Exception as e:
        print(f"❌ KIS 인증 실패: {e}")
        return

    # 1. 전체 종목 수집
    all_stocks = _fetch_all_stocks()
    print(f"📋 전체 종목: {len(all_stocks)}개")
    if not all_stocks:
        print("❌ 종목 수집 실패 — 종료")
        return

    # 2. 코드 패턴 필터
    candidates = _prefilter(all_stocks)
    print(f"📋 패턴 필터 후: {len(candidates)}개")

    # 3. 병렬 예비 점수 계산 (fundamentals + 가격/거래량 필터 + MA)
    pre_results = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = {ex.submit(_score_stock, s): s for s in candidates}
        done = 0
        for fut in as_completed(futures):
            done += 1
            if done % 200 == 0:
                print(f"  진행: {done}/{len(candidates)}")
            result = fut.result()
            if result and result["score"] >= PRE_THRESHOLD:
                pre_results.append(result)

    pre_results.sort(key=lambda x: x["score"], reverse=True)
    print(f"📊 예비 통과 ({PRE_THRESHOLD}점 이상): {len(pre_results)}개")

    # 4. 재무비율 포함 최종 점수 (예비 통과 종목만, 최대 150개)
    final_results = []
    for stock in pre_results[:150]:
        scored = _score_with_ratios(stock)
        if scored["score"] >= MIN_THRESHOLD:
            final_results.append(scored)
        time.sleep(0.3)

    final_results.sort(key=lambda x: x["score"], reverse=True)
    top = final_results[:TOP_N]

    print(f"\n{'='*55}")
    print(f"  🏆 광역 스캔 결과 — 상위 {len(top)}종목 ({MIN_THRESHOLD}점 이상)")
    print(f"{'='*55}")
    for r in top[:20]:
        print(f"  [{r['score']}/13점] {r['name']}({r['code']})  {r['fund']['price']:,}원")

    # 5. screening_candidates 갱신
    _upsert_candidates(top)


if __name__ == "__main__":
    main()
