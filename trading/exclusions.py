"""
관리자가 제외한 종목코드 조회.

관리 화면(스크리닝 종목 관리)에서 관리자가 삭제한 종목은 screening_candidates 의
해당 종목코드 행이 전부 status='rejected' 가 된다 (api/_admin-screening.js).
광역 스캔·스크리닝 메일·자동매매는 이 목록의 종목을 통째로 건너뛴다.

조회에 실패하면 빈 집합으로 넘어가지 않고 예외를 낸다. 빈 집합으로 치면 관리자가
막아둔 종목이 메일에 실리거나 매수될 수 있기 때문이다.
"""
import os

import requests

_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()


def get_excluded_codes() -> set[str]:
    if not (_URL and _KEY):
        return set()
    r = requests.get(
        f"{_URL}/rest/v1/screening_candidates?status=eq.rejected&select=stock_code",
        headers={'apikey': _KEY, 'Authorization': f'Bearer {_KEY}'},
        timeout=10,
    )
    r.raise_for_status()
    return {row['stock_code'] for row in r.json()}
