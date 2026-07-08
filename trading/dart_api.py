"""
DART Open API — 재무비율 조회
https://opendart.fss.or.kr 에서 API 키 무료 발급

환경변수: DART_API_KEY
"""
import io
import os
import zipfile
import xml.etree.ElementTree as ET
import requests
from datetime import datetime

_BASE = 'https://opendart.fss.or.kr/api'
_corp_cache: dict[str, str] = {}   # stock_code → corp_code (세션 내 캐시)
_corp_list: dict[str, str] = {}    # stock_code → corp_code (전체 목록)
_corp_list_loaded = False


def _load_corp_list(dart_key: str) -> bool:
    """기업코드 매핑 로드 — 번들 JSON 우선, 없으면 DART API 다운로드"""
    global _corp_list_loaded
    if _corp_list_loaded:
        return True

    # 번들 JSON (repo에 커밋된 파일)
    json_path = os.path.join(os.path.dirname(__file__), 'corp_codes.json')
    if os.path.exists(json_path):
        import json
        with open(json_path, encoding='utf-8') as f:
            _corp_list.update(json.load(f))
        _corp_list_loaded = True
        return True

    # fallback: DART API 다운로드
    try:
        r = requests.get(
            f'{_BASE}/corpCode.xml',
            params={'crtfc_key': dart_key},
            timeout=30,
        )
        r.raise_for_status()
        with zipfile.ZipFile(io.BytesIO(r.content)) as z:
            name = next(n for n in z.namelist() if n.upper().endswith('.XML'))
            with z.open(name) as f:
                tree = ET.parse(f)
        for item in tree.getroot().findall('list'):
            stock = (item.findtext('stock_code') or '').strip()
            corp  = (item.findtext('corp_code')  or '').strip()
            if stock and corp:
                _corp_list[stock] = corp
        _corp_list_loaded = True
        print(f"  [DART] 기업코드 목록 로드 완료: {len(_corp_list)}개")
        return True
    except Exception as e:
        print(f"  [DART] 기업코드 목록 로드 실패: {e}")
        return False


def _corp_code(stock_code: str, dart_key: str) -> str | None:
    if stock_code in _corp_cache:
        return _corp_cache[stock_code]
    if not _load_corp_list(dart_key):
        return None
    corp = _corp_list.get(stock_code)
    if not corp:
        print(f"  [DART] corp_code 없음 ({stock_code})")
        return None
    _corp_cache[stock_code] = corp
    return corp


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
                if name in result:
                    continue  # 첫 번째(최상위) 값만 사용
                val = (item.get('thstrm_amount') or '').replace(',', '')
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
        result['부채비율'] = round(total_liab / total_equity * 100, 1)

    curr_assets = acct.get('유동자산')
    curr_liab   = acct.get('유동부채')
    if curr_assets is not None and curr_liab:
        result['유동비율'] = round(curr_assets / curr_liab * 100, 1)

    cash = acct.get('현금및현금성자산')
    if cash is not None and curr_liab:
        result['현금비율'] = round(cash / curr_liab * 100, 1)

    op_profit    = acct.get('영업이익')
    interest_exp = acct.get('이자비용') or acct.get('금융비용')
    if op_profit is not None and interest_exp and interest_exp != 0:
        result['이자보상배율'] = round(op_profit / interest_exp * 100, 1)

    return result or None
