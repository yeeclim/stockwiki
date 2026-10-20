"""야간선물 일봉 과거치 덤프 — 수동 실행 전용(probe_night_history.yml).

코스피200 야간선물이 시가 갭을 얼마나 맞히는지 검증하려고, KIS 선물옵션 기간별시세
(FHKIF03020100)로 월물별 정규장('F')·야간('CM') 일봉을 받아 CSV 줄로 찍는다.
2026-10-20 실측: 'CM' 이 야간 일봉을 주고, 소멸 월물은 A01603 까지만 조회된다.

조회만 한다 — 주문·메일·DB 쓰기 없음.
"""
from datetime import date, timedelta

from kis_api import KISApi

_PATH = '/uapi/domestic-futureoption/v1/quotations/inquire-daily-fuopchartprice'
_CONTRACTS = ('A01603', 'A01606', 'A01609', 'A01612')


def main() -> int:
    api = KISApi()
    api.auth()
    print('CSV,market,contract,date,open,close,volume')
    for mrkt in ('F', 'CM'):
        for code in _CONTRACTS:
            seen = set()
            end = date(2026, 10, 20)
            while end > date(2025, 6, 1):
                start = end - timedelta(days=60)
                params = {
                    'FID_COND_MRKT_DIV_CODE': mrkt, 'FID_INPUT_ISCD': code,
                    'FID_INPUT_DATE_1': start.strftime('%Y%m%d'), 'FID_INPUT_DATE_2': end.strftime('%Y%m%d'),
                    'FID_PERIOD_DIV_CODE': 'D',
                }
                body = api._get(_PATH, headers=api._h('FHKIF03020100'), params=params).json()
                for r in body.get('output2') or []:
                    d = r.get('stck_bsop_date')
                    if d and d not in seen and r.get('futs_prpr') not in ('', None):
                        seen.add(d)
                        print(f"CSV,{mrkt},{code},{d},{r['futs_oprc']},{r['futs_prpr']},{r['acml_vol']}")
                end = start - timedelta(days=1)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
