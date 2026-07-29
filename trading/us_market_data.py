"""
미국 주식 시세/재무 데이터 — Yahoo Finance 비공식 API (API 키 불필요)
국내 kis_api.py 의 미국 주식판 역할.

주의: 부채비율(debtToEquity)·유동비율(currentRatio)은 Yahoo financialData 모듈에서
실데이터를 제공하지만, 현금비율·이자보상배율은 Yahoo 무료 API의 재무제표 모듈이
값을 비워서 내려주기 때문에(2026년 기준 라이선스 제한 추정) 신뢰할 수 없어 None으로 둔다.
strategy._score_entry는 ratios 항목이 None이면 해당 배점을 0점 처리하고 넘어가므로
국내 종목에서 FnGuide 조회가 실패했을 때와 동일한 방식으로 안전하게 동작한다.
"""
import time
import requests
import technical_indicators as ti

_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

_NASDAQ_LISTED_URL = 'https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt'
_OTHER_LISTED_URL = 'https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt'

_EXCLUDE_NAME_PATTERNS = (
    'warrant', 'warrants', 'right', 'rights', ' unit', 'units',
    'preferred', ' pfd', 'depositary', 'trust preferred',
)

_QUOTE_FIELDS = ('shortName,regularMarketPrice,regularMarketChangePercent,'
                  'regularMarketVolume,marketCap,trailingPE,priceToBook')
_BATCH_SIZE = 100

_session = requests.Session()
_session.headers.update({'User-Agent': _UA})
_crumb: str | None = None


# ── 전체 종목 목록 ────────────────────────────────────────────────────────────

def fetch_universe() -> list[dict]:
    """NASDAQ + NYSE/AMEX 전체 상장 보통주 목록 (ETF·워런트·우선주·테스트종목 제외)"""
    stocks = _parse_nasdaq_listed() + _parse_other_listed()
    seen = set()
    result = []
    for s in stocks:
        if s['code'] in seen:
            continue
        seen.add(s['code'])
        result.append(s)
    return result


def _parse_nasdaq_listed() -> list[dict]:
    try:
        r = requests.get(_NASDAQ_LISTED_URL, headers={'User-Agent': _UA}, timeout=20)
        r.raise_for_status()
        out = []
        for line in r.text.strip().split('\n')[1:]:
            cols = line.split('|')
            if len(cols) < 8:
                continue
            symbol, name, _market_cat, test_issue, _fin_status, _lot, etf, _next_shares = cols[:8]
            if test_issue == 'Y' or etf == 'Y':
                continue
            if _looks_non_common(name, symbol):
                continue
            out.append({'code': symbol.strip(), 'name': name.strip(), 'sector': 'NASDAQ'})
        print(f"📋 NASDAQ: {len(out)}종목 수집")
        return out
    except Exception as e:
        print(f"⚠️  NASDAQ 목록 조회 실패: {e}")
        return []


def _parse_other_listed() -> list[dict]:
    try:
        r = requests.get(_OTHER_LISTED_URL, headers={'User-Agent': _UA}, timeout=20)
        r.raise_for_status()
        exch_map = {'N': 'NYSE', 'A': 'AMEX', 'P': 'ARCA', 'Z': 'BATS', 'V': 'IEX'}
        out = []
        for line in r.text.strip().split('\n')[1:]:
            cols = line.split('|')
            if len(cols) < 8:
                continue
            act_symbol, name, exchange, _cqs, etf, _lot, test_issue, _nasdaq_symbol = cols[:8]
            if test_issue == 'Y' or etf == 'Y':
                continue
            if _looks_non_common(name, act_symbol):
                continue
            out.append({
                'code': act_symbol.strip(),
                'name': name.strip(),
                'sector': exch_map.get(exchange, exchange or 'NYSE'),
            })
        print(f"📋 NYSE/AMEX: {len(out)}종목 수집")
        return out
    except Exception as e:
        print(f"⚠️  NYSE/AMEX 목록 조회 실패: {e}")
        return []


def _looks_non_common(name: str, symbol: str) -> bool:
    n = name.lower()
    if any(p in n for p in _EXCLUDE_NAME_PATTERNS):
        return True
    if not symbol or not symbol.replace('.', '').replace('-', '').isalnum():
        return True
    return False


# ── 인증 (쿠키+크럼) ──────────────────────────────────────────────────────────

def _ensure_auth():
    global _crumb
    if _crumb:
        return
    try:
        _session.get('https://fc.yahoo.com', timeout=15)
        r = _session.get('https://query1.finance.yahoo.com/v1/test/getcrumb', timeout=15)
        _crumb = r.text.strip()
    except Exception as e:
        print(f"⚠️  Yahoo 인증 실패: {e}")
        _crumb = ''


# ── 배치 시세 (가격/거래량/시총/PER/PBR) ─────────────────────────────────────

def get_quotes_batch(symbols: list[str]) -> dict[str, dict]:
    """{symbol: quote_dict} 반환. 조회 실패한 심볼은 결과에서 빠진다."""
    _ensure_auth()
    out: dict[str, dict] = {}
    for i in range(0, len(symbols), _BATCH_SIZE):
        chunk = symbols[i:i + _BATCH_SIZE]
        try:
            r = _session.get(
                'https://query1.finance.yahoo.com/v7/finance/quote',
                params={'symbols': ','.join(chunk), 'fields': _QUOTE_FIELDS, 'crumb': _crumb},
                timeout=20,
            )
            r.raise_for_status()
            for q in r.json().get('quoteResponse', {}).get('result', []):
                out[q['symbol']] = q
        except Exception as e:
            print(f"⚠️  배치 시세 조회 실패 ({i}~{i + len(chunk)}): {e}")
        time.sleep(0.25)
    return out


# ── 이동평균 (MA5/20/60 + 골든크로스) ────────────────────────────────────────

def get_ma_data(symbol: str) -> dict:
    """차트 API(인증 불필요)의 일봉 종가로 MA5/20/60 및 골든크로스 계산.
    국내 kis_api.get_ma_data 와 동일한 정의: 오늘 MA5>MA20 이고 어제는 MA5<=MA20 였으면 골든크로스.
    """
    try:
        r = requests.get(
            f'https://query1.finance.yahoo.com/v8/finance/chart/{symbol}',
            params={'interval': '1d', 'range': '4mo'},
            headers={'User-Agent': _UA},
            timeout=15,
        )
        r.raise_for_status()
        result = r.json()['chart']['result'][0]
        quote = result['indicators']['quote'][0]
        raw_closes = quote['close']
        raw_volumes = quote.get('volume') or [0] * len(raw_closes)
        pairs = [(c, v) for c, v in zip(raw_closes, raw_volumes) if c is not None]
        closes = [c for c, _ in pairs]
        volumes = [(v or 0) for _, v in pairs]
        if len(closes) < 20:
            return {}

        def ma(n):
            return round(sum(closes[-n:]) / n, 4) if len(closes) >= n else None

        def ma_prev(n):
            return round(sum(closes[-(n + 1):-1]) / n, 4) if len(closes) >= n + 1 else None

        ma5, ma20, ma60 = ma(5), ma(20), ma(60)
        p5, p20 = ma_prev(5), ma_prev(20)

        # closes/volumes는 이미 과거→최신(오름차순) 순서 (Yahoo 차트 API 기본 응답 순서)
        rsi_rebound, rsi_now = ti.rsi_oversold_rebound(closes)
        basing = ti.basing_near_low(closes)
        vol_declining = ti.volume_declining(volumes)

        return {
            'ma5': ma5, 'ma20': ma20, 'ma60': ma60,
            'golden_cross': bool(ma5 and ma20 and p5 and p20 and ma5 > ma20 and p5 <= p20),
            'above_ma20': bool(ma5 and ma20 and ma5 > ma20),
            'rsi': rsi_now,
            'rsi_rebound': rsi_rebound,
            'basing': basing,
            'volume_declining': vol_declining,
        }
    except Exception:
        return {}


# ── 재무비율 (부채비율·유동비율만 신뢰 가능) ─────────────────────────────────

def get_ratios(symbol: str) -> dict | None:
    _ensure_auth()
    try:
        r = _session.get(
            f'https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}',
            params={'modules': 'financialData', 'crumb': _crumb},
            timeout=15,
        )
        r.raise_for_status()
        result = r.json().get('quoteSummary', {}).get('result')
        if not result:
            return None
        fd = result[0].get('financialData') or {}
        current_ratio = (fd.get('currentRatio') or {}).get('raw')
        debt_to_equity = (fd.get('debtToEquity') or {}).get('raw')
        return {
            '부채비율': debt_to_equity,
            '유동비율': current_ratio * 100 if current_ratio is not None else None,
            '현금비율': None,
            '이자보상배율': None,
        }
    except Exception:
        return None


# ── 환율 ──────────────────────────────────────────────────────────────────────

def get_usd_krw_rate() -> float:
    """국내와 동일한 시가총액 4천억원 게이트를 그대로 재사용하기 위한 환산용 환율"""
    try:
        r = requests.get('https://open.er-api.com/v6/latest/USD', timeout=10)
        r.raise_for_status()
        return float(r.json()['rates']['KRW'])
    except Exception:
        return 1350.0
