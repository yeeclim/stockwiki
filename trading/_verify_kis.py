"""
KIS API 리팩터링 검증 — 읽기 전용 호출만 (이메일/게시판/카톡/주문 없음).

brokers.KISApi(실매매 베이스)와 kis_api.KISApi(스크리닝 확장)를 실제 KIS
OpenAPI에 붙여 응답 스키마가 리팩터 전과 동일한지 확인한다.
KIS 토큰 발급은 1분당 1회 제한이 있어 한 번만 발급하고 두 인스턴스가 공유한다.
"""
import os
import sys
import traceback

CODE = "005930"  # 삼성전자
fails = []


def check(label, fn):
    try:
        r = fn()
        print(f"  OK  {label}: {r!r}"[:400])
        return r
    except Exception as e:
        print(f"  FAIL {label}: {type(e).__name__}: {e}")
        traceback.print_exc()
        fails.append(label)
        return None


print("=" * 60)
print("[1] kis_api.KISApi (screen.py 스크리닝 경로) — 토큰 발급")
from kis_api import KISApi

s = KISApi()
check("auth", lambda: s.auth() or "ok")

print()
print("[2] brokers.KISApi (main.py 실매매 경로) — 토큰 공유")
from brokers import create_api

b = create_api("kis", {
    "kis_app_key": os.environ["KIS_APP_KEY"],
    "kis_app_secret": os.environ["KIS_APP_SECRET"],
    "kis_account_no": os.environ["KIS_ACCOUNT_NO"],
    "kis_account_prod_code": os.environ.get("KIS_ACCOUNT_PROD_CODE", "01"),
})
b.token = s.token  # 재발급 제한 회피

fb = check("get_fundamentals", lambda: b.get_fundamentals(CODE))
mb = check("get_ma_data", lambda: b.get_ma_data(CODE))
check("get_price", lambda: b.get_price(CODE))
check("get_cash", lambda: b.get_cash())
check("get_holdings", lambda: b.get_holdings(CODE))

if fb is not None:
    assert set(fb) == {"price", "per", "pbr", "volume", "prdy_ctrt", "open", "prdy_clpr"}, \
        f"base fundamentals keys 변경됨: {sorted(fb)}"
    print(f"  ++  base fundamentals keys 유지 (market_cap 없음 확인)")
if mb is not None:
    assert "rsi" not in mb, "base get_ma_data 에 rsi 가 생김 — 실매매 동작 변화!"
    print(f"  ++  base ma_data keys 유지: {sorted(mb)}")

print()
print("[3] kis_api.KISApi 스크리닝 전용 확장")
fs = check("get_fundamentals(+market_cap)", lambda: s.get_fundamentals(CODE))
ms = check("get_ma_data(+지표)", lambda: s.get_ma_data(CODE))
check("get_financial_ratios", lambda: s.get_financial_ratios(CODE))
check("get_investor_trend(KOSPI)", lambda: s.get_investor_trend("0001", "KSP"))
import kr_market_data as kmd

check("get_futures_open_interest",
      lambda: s.get_futures_open_interest(kmd.kospi200_futures_code()))

if fs is not None:
    assert "market_cap" in fs, "스크리닝 fundamentals 에 market_cap 누락 — 회귀!"
    print(f"  ++  스크리닝 market_cap = {fs.get('market_cap')}")
if ms is not None:
    assert {"rsi", "rsi_rebound", "basing", "volume_declining"} <= set(ms), \
        f"스크리닝 ma_data 지표 누락: {sorted(ms)}"
    print(f"  ++  스크리닝 지표 OK: rsi={ms.get('rsi')} "
          f"rebound={ms.get('rsi_rebound')} basing={ms.get('basing')}")

print()
print("=" * 60)
if fails:
    print(f"실패: {fails}")
    sys.exit(1)
print("전체 통과")
