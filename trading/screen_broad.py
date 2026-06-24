"""
광역 종목 스캔 — 전체 KOSPI/KOSDAQ 스캔으로 screening_candidates 자동 갱신
GitHub Actions 매주 월요일 07:00 KST 실행

흐름:
  1. KRX 공공 API → 전체 상장 종목 코드 수집
  2. 기초 필터 (가격·거래량)로 1500→300 수준으로 축소
  3. KIS API 병렬 조회 (fundamentals + MA) → 예비 점수 계산
  4. 예비 점수 4점 이상 종목만 FnGuide 재무비율 조회 → 최종 점수
  5. 최종 점수 4점 이상 종목을 screening_candidates 테이블에 upsert
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

# KIS API 인스턴스 (auth()는 main에서 한 번만)
_api: KISApi | None = None

MAX_WORKERS   = 5    # 병렬 스레드 수 (KIS API rate limit 고려)
CALL_DELAY    = 0.1  # 스레드별 API 호출 간 최소 대기(초)
PRE_THRESHOLD = 4    # 예비 점수 이상이면 재무비율 조회
MIN_THRESHOLD = 4    # 최종 점수 이상이면 candidates에 등록
TOP_N         = 60   # candidates에 저장할 최대 종목 수


# ── KRX 전체 종목 조회 ──────────────────────────────────────────────────────────

def _fetch_krx_stocks() -> list[dict]:
    """KRX 공공 데이터 포털에서 KOSPI/KOSDAQ 전체 종목 조회"""
    today = datetime.now().strftime("%Y%m%d")
    all_stocks = []
    for mkt_id, sector in [("STK", "KOSPI"), ("KSQ", "KOSDAQ")]:
        try:
            r = requests.post(
                "http://data.krx.co.kr/comm/bldAttendant/getJsonData.cmd",
                data={
                    "bld":          "dbms/MDC/STAT/standard/MDCSTAT01501",
                    "mktId":        mkt_id,
                    "trdDd":        today,
                    "share":        "1",
                    "money":        "1",
                    "csvxls_isNo":  "false",
                },
                headers={
                    "Content-Type": "application/x-www-form-urlencoded",
                    "User-Agent":   "Mozilla/5.0",
                    "Referer":      "http://data.krx.co.kr/",
                },
                timeout=20,
            )
            r.raise_for_status()
            for item in r.json().get("OutBlock_1", []):
                code   = item.get("ISU_SRT_CD", "")
                name   = item.get("ISU_ABBRV", "")
                price  = int(item.get("TDD_CLSPRC",  "0").replace(",", "") or 0)
                volume = int(item.get("ACC_TRDVOL",  "0").replace(",", "") or 0)
                if code and name:
                    all_stocks.append({
                        "code":   code,
                        "name":   name,
                        "sector": sector,
                        "price":  price,
                        "volume": volume,
                    })
        except Exception as e:
            print(f"⚠️  KRX {mkt_id} 조회 실패: {e}")
    return all_stocks


def _prefilter(stocks: list[dict]) -> list[dict]:
    """기초 필터: ETF/관리종목 제외, 가격·거래량 기준"""
    filtered = []
    for s in stocks:
        code, price, volume = s["code"], s["price"], s["volume"]
        # ETF·ETN: 6자리가 아니거나 1로 시작(ETF) — 단순 근사 필터
        if not (len(code) == 6 and code.isdigit()):
            continue
        if code.startswith("1"):   # ETF 코드 대역
            continue
        if price < 1_000 or price > 800_000:
            continue
        if volume < 50_000:
            continue
        filtered.append(s)
    return filtered


# ── 종목 점수 계산 (스레드 내에서 실행) ─────────────────────────────────────────

def _score_stock(stock: dict) -> dict | None:
    """단일 종목 예비 점수 계산 (fundamentals + MA만, 재무비율 없이)"""
    global _api
    code, name = stock["code"], stock["name"]
    try:
        time.sleep(CALL_DELAY)
        fund    = _api.get_fundamentals(code)
        ma_data = _api.get_ma_data(code)
        score, _, _ = _score_entry(fund, ma_data, ratios=None)
        return {**stock, "score": score, "fund": fund, "ma": ma_data}
    except Exception:
        return None


def _score_with_ratios(stock: dict) -> dict:
    """재무비율까지 포함한 최종 점수 계산"""
    global _api
    try:
        ratios = _api.get_financial_ratios(stock["code"])
        score, _, _ = _score_entry(stock["fund"], stock["ma"], ratios)
        return {**stock, "score": score, "ratios": ratios}
    except Exception:
        return stock


# ── Supabase 저장 ──────────────────────────────────────────────────────────────

def _upsert_candidates(candidates: list[dict]):
    """screening_candidates 테이블에 upsert (기존 시스템 종목 삭제 후 교체)"""
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print("⚠️  Supabase 환경변수 없음 — 저장 생략")
        return

    headers = {
        "apikey":        _SUPABASE_KEY,
        "Authorization": f"Bearer {_SUPABASE_KEY}",
        "Content-Type":  "application/json",
    }

    # 기존 시스템 자동 추가 종목 삭제 (source='system')
    try:
        requests.delete(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates"
            f"?source=eq.system&user_id=is.null",
            headers=headers,
            timeout=10,
        )
    except Exception as e:
        print(f"⚠️  기존 시스템 종목 삭제 실패: {e}")

    # 새 종목 upsert
    rows = [
        {
            "stock_code": c["code"],
            "stock_name": c["name"],
            "sector":     c.get("sector", ""),
            "is_active":  True,
            "source":   "system",
        }
        for c in candidates
    ]
    try:
        resp = requests.post(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates",
            headers={**headers, "Prefer": "resolution=merge-duplicates"},
            json=rows,
            timeout=15,
        )
        if resp.ok:
            print(f"✅ screening_candidates 갱신 완료 — {len(rows)}종목")
        else:
            print(f"⚠️  저장 실패: {resp.status_code} {resp.text[:200]}")
    except Exception as e:
        print(f"⚠️  저장 오류: {e}")


# ── 메인 ──────────────────────────────────────────────────────────────────────

def main():
    global _api

    print("🔍 전체 KOSPI/KOSDAQ 광역 스캔 시작")

    # KIS API 인증
    _api = KISApi()
    try:
        _api.auth()
    except Exception as e:
        print(f"❌ KIS 인증 실패: {e}")
        return

    # 1. 전체 종목 수집
    all_stocks = _fetch_krx_stocks()
    print(f"📋 KRX 전체 종목: {len(all_stocks)}개")

    # 2. 기초 필터
    candidates = _prefilter(all_stocks)
    print(f"📋 기초 필터 후: {len(candidates)}개")

    # 3. 병렬 예비 점수 계산 (fundamentals + MA)
    pre_results = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = {ex.submit(_score_stock, s): s for s in candidates}
        done = 0
        for fut in as_completed(futures):
            done += 1
            if done % 100 == 0:
                print(f"  진행: {done}/{len(candidates)}")
            result = fut.result()
            if result and result["score"] >= PRE_THRESHOLD:
                pre_results.append(result)

    pre_results.sort(key=lambda x: x["score"], reverse=True)
    print(f"📊 예비 통과 ({PRE_THRESHOLD}점 이상): {len(pre_results)}개")

    # 4. 재무비율 포함 최종 점수 (예비 통과 종목만)
    final_results = []
    for stock in pre_results[:150]:  # 최대 150개만 재무비율 조회
        scored = _score_with_ratios(stock)
        if scored["score"] >= MIN_THRESHOLD:
            final_results.append(scored)
        time.sleep(0.3)

    final_results.sort(key=lambda x: x["score"], reverse=True)
    top = final_results[:TOP_N]

    print(f"\n{'='*55}")
    print(f"  🏆 광역 스캔 결과 — 상위 {len(top)}종목 (최종 {MIN_THRESHOLD}점 이상)")
    print(f"{'='*55}")
    for r in top[:20]:
        print(f"  [{r['score']}/10점] {r['name']}({r['code']})  {r['fund']['price']:,}원")

    # 5. screening_candidates 갱신
    _upsert_candidates(top)


if __name__ == "__main__":
    main()
