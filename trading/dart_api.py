"""
DART Open API — 재무비율 조회
https://opendart.fss.or.kr 에서 API 키 무료 발급

환경변수: DART_API_KEY
"""
import os
import requests
from datetime import datetime

_BASE = 'https://opendart.fss.or.kr/api'
_corp_cache: dict[str, str] = {}  # stock_code → corp_code (세션 내 캐시)


def _corp_code(stock_code: str, dart_key: str) -> str | None:
    if stock_code in _corp_cache:
        return _corp_cache[stock_code]
    try:
        r = requests.get(
            f'{_BASE}/company.json',
            params={'crtfc_key': dart_key, 'stock_code': stock_code},
            timeout=10,
        )
        r.raise_for_status()
        d = r.json()
        if d.get('status') != '000':
            print(f"  [DART] corp_code 실패 ({stock_code}): status={d.get('status')} msg={d.get('message')}")
            return None
        code = d['corp_code']
        _corp_cache[stock_code] = code
        return code
    except Exception as e:
        print(f"  [DART] corp_code 예외 ({stock_code}): {e}")
        return None


def _accounts(corp_code: str, dart_key: str, year: str) -> dict:
    """연결재무제표(CFS) 우선, 없으면 별도(OFS) — 사업보고서(연간)"""
    for fs_div in ('CFS', 'OFS'):
        try:
            r = requests.get(
                f'{_BASE}/fnlttSinglAcntAll.json',
                params={
                    'crtfc_key':  dart_key,
                    'corp_code':  corp_code,
                    'bsns_year':  year,
                    'reprt_code': '11011',  # 사업보고서
                    'fs_div':     fs_div,
                },
                timeout=15,
            )
            if not r.ok:
                continue
            d = r.json()
            if d.get('status') != '000':
                continue
            result = {}
            for item in d.get('list', []):
                name = item.get('account_nm', '').strip()
                val  = (item.get('thstrm_amount') or '').replace(',', '')
                try:
                    result[name] = float(val)
                except ValueError:
                    pass
            if result:
                return result
        except Exception:
            continue
    return {}


def get_financial_ratios(stock_code: str, dart_key: str | None = None) -> dict | None:
    """
    DART API로 재무비율 4종 계산.
    dart_key 미지정 시 환경변수 DART_API_KEY 사용.
    실패 시 None 반환.
    """
    key = dart_key or os.environ.get('DART_API_KEY', '').strip()
    if not key:
        print(f"  [DART] DART_API_KEY 미설정")
        return None

    corp = _corp_code(stock_code, key)
    if not corp:
        return None

    cur_year = datetime.now().year
    acct = {}
    for year in [str(cur_year - 1), str(cur_year - 2)]:
        acct = _accounts(corp, key, year)
        if acct:
            break

    if not acct:
        return None

    result = {}

    total_liab   = acct.get('부채총계')
    total_equity = acct.get('자본총계')
    if total_liab is not None and total_equity:
        result['debt_ratio'] = round(total_liab / total_equity * 100, 1)

    curr_assets = acct.get('유동자산')
    curr_liab   = acct.get('유동부채')
    if curr_assets is not None and curr_liab:
        result['current_ratio'] = round(curr_assets / curr_liab * 100, 1)

    cash = acct.get('현금및현금성자산')
    if cash is not None and curr_liab:
        result['cash_ratio'] = round(cash / curr_liab * 100, 1)

    op_profit    = acct.get('영업이익')
    interest_exp = acct.get('이자비용')
    if op_profit is not None and interest_exp and interest_exp != 0:
        result['interest_coverage'] = round(op_profit / interest_exp * 100, 1)

    return result or None
