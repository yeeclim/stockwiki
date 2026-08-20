"""
국내 지수/선물 시세 — 네이버 금융 실시간 폴링 API (비공식, API 키 불필요)
us_market_data.py 의 국내판 역할. 코스피·코스닥·코스피200선물 가격/등락률을 담당하고,
선물 미결제약정은 인증이 필요해 kis_api.KISApi 쪽에서 별도로 조회한다.
"""
import os
from datetime import datetime

import requests

_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

_URL = 'https://polling.finance.naver.com/api/realtime/domestic/index/KOSPI,KOSDAQ,FUT'

_LABELS = {'KOSPI': '코스피', 'KOSDAQ': '코스닥', 'FUT': '코스피200 선물'}

# Naver 등락 코드: 1=상한 2=상승 3=보합 4=하한 5=하락
_FALL_CODES = {'4', '5'}


def get_quotes() -> dict[str, dict]:
    """{'KOSPI': {...}, 'KOSDAQ': {...}, 'FUT': {...}} 반환.
    각 값은 {'label', 'price', 'pct'}. 조회 실패 시 빈 dict."""
    try:
        r = requests.get(_URL, headers={'User-Agent': _UA}, timeout=8)
        r.raise_for_status()
        out = {}
        for item in r.json().get('datas', []):
            code = item.get('itemCode')
            if code not in _LABELS:
                continue
            try:
                price = float(item.get('closePriceRaw'))
                pct = float(item.get('fluctuationsRatioRaw'))
            except (TypeError, ValueError):
                continue
            sign = (item.get('compareToPreviousPrice') or {}).get('code')
            if sign in _FALL_CODES:
                pct = -abs(pct)
            else:
                pct = abs(pct)
            out[code] = {'label': _LABELS[code], 'price': price, 'pct': pct}
        return out
    except Exception as e:
        print(f"⚠️  국내 지수 조회 실패: {e}")
        return {}


# ── 코스피200 선물 종목코드 ───────────────────────────────────────────────────
# 분기월물(3·6·9·12월)만 사용하는 근사치 — KIS 종목코드 형식이 실계좌로 검증되지
# 않았으므로 필요 시 KIS_KOSPI200_FUTURES_CODE 환경변수로 직접 지정할 수 있다.
_FUT_MONTH_CODE = {3: 'H', 6: 'M', 9: 'U', 12: 'Z'}


def kospi200_futures_code(today: datetime | None = None) -> str:
    override = os.environ.get('KIS_KOSPI200_FUTURES_CODE', '').strip()
    if override:
        return override
    today = today or datetime.now()
    for m in (3, 6, 9, 12):
        if m >= today.month:
            return f"101{_FUT_MONTH_CODE[m]}{str(today.year)[-1]}"
    return f"101{_FUT_MONTH_CODE[3]}{str(today.year + 1)[-1]}"
