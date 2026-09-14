"""
국내 지수/선물 시세 — 네이버 금융 실시간 폴링 API (비공식, API 키 불필요)
us_market_data.py 의 국내판 역할. 코스피·코스닥·코스피200선물 가격/등락률을 담당하고,
선물 미결제약정은 인증이 필요해 kis_api.KISApi 쪽에서 별도로 조회한다.
"""
import io
import os
import re
import zipfile
from datetime import datetime

import requests
import urllib3

# 마스터파일 CDN(new.real.download.dws.co.kr)이 중간 인증서를 안 내려줘 검증이 실패한다.
# KIS 공식 샘플코드도 같은 이유로 검증을 끄고 받는다. 공개 종목코드 파일이라 위험이 없다.
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

_URL = 'https://polling.finance.naver.com/api/realtime/domestic/index/KOSPI,KOSDAQ,FUT'

_LABELS = {'KOSPI': '코스피', 'KOSDAQ': '코스닥', 'FUT': '코스피200 선물'}

# Naver 등락 코드: 1=상한 2=상승 3=보합 4=하한 5=하락
_FALL_CODES = {'4', '5'}


def _to_float(*values) -> float | None:
    for v in values:
        try:
            return float(str(v).replace(',', ''))
        except (TypeError, ValueError):
            continue
    return None


def get_quotes() -> dict[str, dict]:
    """{'KOSPI': {...}, 'KOSDAQ': {...}, 'FUT': {...}} 반환.
    각 값은 {'label', 'price', 'pct', 'volume'}. volume은 없으면 None. 조회 실패 시 빈 dict."""
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
            volume = _to_float(
                item.get('accumulatedTradingVolume'),
                item.get('accumulatedTradingVolumeRaw'),
                item.get('quant'),
            )
            # traded_at: 마지막 체결 시각. 장 시작 전에는 전일 값이 그대로 내려오므로
            # '오늘 신호'로 쓸 수 있는지 판별하는 데 쓴다.
            out[code] = {'label': _LABELS[code], 'price': price, 'pct': pct, 'volume': volume,
                         'traded_at': item.get('localTradedAt')}
        return out
    except Exception as e:
        print(f"⚠️  국내 지수 조회 실패: {e}")
        return {}


# ── 코스피200 선물 종목코드 ───────────────────────────────────────────────────
# 형식: "A" + (연도-2010, 3자리) + (월, 2자리) — 예: 2026년 12월물 = A01612.
#
# 최근월물은 KIS 마스터파일에서 직접 읽는다. 예전엔 "3·6·9·12월 중 이번 달 이상"
# 이라는 월 단위 근사로 계산했는데, 선물 만기는 그 달 두 번째 목요일이라 만기일
# 다음날부터 월말까지(분기마다 2~3주) 이미 소멸한 월물 코드를 조회하고 있었다.
# (예: 2026-09-14 → A01609 반환. 9월물은 2026-09-10에 만기.)
# 마스터파일에는 소멸한 월물이 빠져 있어 첫 행이 곧 최근월물이다.
#
# KIS_KOSPI200_FUTURES_CODE 환경변수로 직접 덮어쓸 수 있다.
_MASTER_BASE = 'https://new.real.download.dws.co.kr/common/master/'
# fo_cme_code(야간선물, 392B)가 fo_idx_code_mts(지수선물옵션 전체, 92KB)보다 훨씬
# 가볍고 월물 구성이 같아 먼저 시도한다. 야간시장이 없어지면 두 번째가 받아준다.
_MASTER_FILES = ('fo_cme_code.mst.zip', 'fo_idx_code_mts.mst.zip')
# 각 행은 "상품종류(1=선물) + 종목코드 + 표준코드 + 만기 + ..." 인데 구분자가 다르다.
#   fo_cme_code     (고정폭)  : "1A01612   KR4A016C0004F 202612"
#   fo_idx_code_mts (파이프)  : "1|A01612|KR4A016C0004|F 202612|..."
# 그래서 구분자를 선택적으로 두고, 만기는 별도 필드 대신 종목코드에서 유도한다.
#   A01612 → 연도 2010+016 = 2026, 월 12
_FUT_CODE_RE = re.compile(r'^1\|?(A(\d{3})(\d{2}))')

_front_month_cache: str | None = None


def _front_month_from_master() -> str | None:
    """마스터파일에서 코스피200 선물 최근월물 코드를 읽는다. 실패하면 None."""
    global _front_month_cache
    if _front_month_cache:
        return _front_month_cache
    for name in _MASTER_FILES:
        try:
            r = requests.get(_MASTER_BASE + name, headers={'User-Agent': _UA},
                             timeout=20, verify=False)
            r.raise_for_status()
            with zipfile.ZipFile(io.BytesIO(r.content)) as z:
                raw = z.read(z.namelist()[0]).decode('cp949', errors='replace')
        except Exception as e:
            print(f"⚠️  선물 마스터파일({name}) 조회 실패: {e}")
            continue

        # 상품종류 1 = 단일 종목(선물). 2는 스프레드라 제외한다.
        rows = []
        for line in raw.splitlines():
            m = _FUT_CODE_RE.match(line)
            if not m:
                continue
            month = int(m.group(3))
            if not 1 <= month <= 12:
                continue
            maturity = (2010 + int(m.group(2))) * 100 + month
            rows.append((maturity, m.group(1)))
        # 소멸한 월물은 마스터에서 빠지므로 만기가 가장 이른 것이 최근월물이다.
        if rows:
            _front_month_cache = min(rows)[1]
            return _front_month_cache
    return None


def kospi200_futures_code(today: datetime | None = None) -> str:
    override = os.environ.get('KIS_KOSPI200_FUTURES_CODE', '').strip()
    if override:
        return override
    code = _front_month_from_master()
    if code:
        return code
    # 폴백: 마스터파일을 못 받았을 때만 쓰는 월 단위 근사(만기 주간엔 틀릴 수 있다).
    today = today or datetime.now()
    for m in (3, 6, 9, 12):
        if m >= today.month:
            return f"A{today.year - 2010:03d}{m:02d}"
    return f"A{today.year + 1 - 2010:03d}03"
