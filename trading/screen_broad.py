"""
광역 종목 스캔 — 전체 KOSPI/KOSDAQ 스캔으로 screening_candidates 자동 갱신
GitHub Actions 매일 07:00 KST 실행

흐름:
  1. FinanceDataReader → 전체 상장 종목 코드+이름 수집
  2. 코드 패턴 필터 (ETF·우선주 제외)
  3. KIS API 병렬 조회 (fundamentals + 가격/거래량 필터 + MA) → 예비 점수
  4. 예비 점수 PRE_THRESHOLD 이상 종목만 FnGuide 재무비율 조회 → 최종 점수
  5. 최종 점수 MIN_THRESHOLD 이상 종목을 screening_candidates 테이블에 upsert
     단, 결과가 0개이거나 저장이 실패하면 기존 candidates를 보존
"""
import os
import time
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

from exclusions import get_excluded_codes
from kis_api import KISApi
from strategy import _score_entry

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
_SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

_api: KISApi | None = None

MAX_WORKERS   = 5    # 병렬 스레드 수
CALL_DELAY    = 0.15 # 스레드별 API 호출 간 최소 대기(초)
PRE_THRESHOLD = 5    # 예비 점수 이상이면 재무비율 조회 (10점 만점 중 재무비율 4종(각 0.5점) 제외한 예비 최대 8점 기준)
MIN_THRESHOLD = 6    # 최종 점수 이상이면 candidates에 등록 (strategy.BUY_THRESHOLD와 동일)
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
    """보통주만 남긴다.

    KRX 단축코드는 마지막 자리가 0 이면 보통주, 5/7/9/K 등이면 우선주다.
    예전엔 "1로 시작 = ETF" 로 걸러서 KB금융(105560)·한미약품(128940)·
    알테오젠(196170) 같은 보통주가 통째로 빠졌다. FinanceDataReader 의
    KOSPI/KOSDAQ 목록에는 ETF 가 없으므로 앞자리로 거를 이유가 없다.
    2024년 이후 신규 코드는 영문이 섞일 수 있어(예: 0126Z0) 숫자만 허용하지 않는다.
    """
    filtered = []
    for s in stocks:
        code = s["code"].upper()
        if len(code) != 6 or not code.isalnum():
            continue
        if not code.endswith("0"):        # 우선주
            continue
        if "스팩" in s["name"]:            # 기업인수목적회사
            continue
        filtered.append({**s, "code": code})
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
    """screening_candidates 의 시스템 종목을 이번 스캔 결과로 교체한다.

    예전엔 "전부 삭제 → 새로 삽입" 이었고 삭제 응답도 확인하지 않아, 삽입이 실패하면
    후보가 0개가 됐다(2026-06-24 복구 마이그레이션이 필요했던 사고와 같은 구조).
    이제는 ① 새 종목 추가/재활성화가 성공한 뒤에만 ② 빠진 종목을 비활성화한다.
    기존 행을 지우지 않으므로 ai_reason 등 부가 정보도 유지된다.
    """
    if not candidates:
        print("⚠️  후보 종목 없음 — 기존 candidates 보존")
        return

    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print("⚠️  Supabase 환경변수 없음 — 저장 생략")
        return

    base = f"{_SUPABASE_URL}/rest/v1/screening_candidates"
    headers = {
        "apikey":        _SUPABASE_KEY,
        "Authorization": f"Bearer {_SUPABASE_KEY}",
        "Content-Type":  "application/json",
    }
    new_codes = [c["code"] for c in candidates]
    codes_param = ",".join(new_codes)

    try:
        # 관리자 수동 추가(admin) 행도 "이미 있음"으로 본다 — 같은 종목을 system 으로 또 넣으면
        # 고유 인덱스(stock_code, user_id) 충돌로 갱신 전체가 실패한다.
        # 활성/비활성은 system 행만 건드린다 (수동 추가 종목은 광역 스캔 결과와 무관하게 유지).
        r = requests.get(
            f"{base}?select=stock_code&source=in.(system,admin)&user_id=is.null",
            headers=headers, timeout=10,
        )
        r.raise_for_status()
        existing = {row["stock_code"] for row in r.json()}

        # ① 기존에 있던 종목은 재활성화 — 관리자가 제외한(rejected) 종목은 되살리지 않는다
        r = requests.patch(
            f"{base}?source=eq.system&user_id=is.null&status=neq.rejected"
            f"&stock_code=in.({codes_param})",
            headers=headers, json={"is_active": True}, timeout=10,
        )
        r.raise_for_status()

        # ② 없던 종목은 삽입
        rows = [
            {
                "stock_code": c["code"],
                "stock_name": c["name"],
                "sector":     c.get("sector", ""),
                "is_active":  True,
                "source":     "system",
            }
            for c in candidates if c["code"] not in existing
        ]
        if rows:
            r = requests.post(base, headers={**headers, "Prefer": "return=minimal"},
                              json=rows, timeout=30)
            r.raise_for_status()

        # ③ 앞 단계가 모두 성공했을 때만, 이번 결과에서 빠진 종목을 비활성화
        r = requests.patch(
            f"{base}?source=eq.system&user_id=is.null&stock_code=not.in.({codes_param})",
            headers=headers, json={"is_active": False}, timeout=10,
        )
        r.raise_for_status()
        print(f"✅ screening_candidates 갱신 완료 — 활성 {len(new_codes)}종목 (신규 {len(rows)})")
    except requests.RequestException as e:
        detail = getattr(e.response, "text", "")[:200] if getattr(e, "response", None) is not None else ""
        print(f"⚠️  후보 갱신 실패 — 기존 후보는 비활성화하지 않음: {e} {detail}")


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

    # 관리자가 제외한 종목은 후보에 올리지 않는다 (조회 실패 시 갱신 자체를 건너뜀)
    try:
        excluded = get_excluded_codes()
    except Exception as e:
        print(f"❌ 제외 종목 조회 실패 — 후보 갱신 생략: {e}")
        return
    final_results = [r for r in final_results if r["code"] not in excluded]

    final_results.sort(key=lambda x: x["score"], reverse=True)
    top = final_results[:TOP_N]

    print(f"\n{'='*55}")
    print(f"  🏆 광역 스캔 결과 — 상위 {len(top)}종목 ({MIN_THRESHOLD}점 이상)")
    print(f"{'='*55}")
    for r in top[:20]:
        print(f"  [{r['score']}/10점] {r['name']}({r['code']})  {r['fund']['price']:,}원")

    # 5. screening_candidates 갱신
    _upsert_candidates(top)


if __name__ == "__main__":
    main()
