"""KIS 시장별 투자자매매동향 원본 확인 — 수동 실행 전용(probe_investor_flow.yml).

수급 신호를 수량(*_qty)에서 거래대금(*_tr_pbmn)으로 바꾸기 전에 두 가지를 실측한다.
  1) 같은 날 수량과 금액의 부호가 실제로 갈리는가
  2) 금액 단위 (토스증권 등 화면의 '억' 값과 비교)

조회만 한다 — 주문·메일·DB 쓰기 없음. 확인이 끝나면 이 파일과 워크플로를 지운다.
"""
from datetime import datetime

import pytz

from kis_api import KISApi

_FIELDS = ('frgn_ntby_qty', 'frgn_ntby_tr_pbmn', 'orgn_ntby_qty', 'orgn_ntby_tr_pbmn',
           'prsn_ntby_qty', 'prsn_ntby_tr_pbmn')


def main() -> None:
    api = KISApi()
    today = datetime.now(pytz.timezone('Asia/Seoul')).strftime('%Y%m%d')
    print(f'KST 기준일 {today}')
    for label, code, mkt in (('코스피', '0001', 'KSP'), ('코스닥', '1001', 'KSQ')):
        r = api._get(
            '/uapi/domestic-stock/v1/quotations/inquire-investor-daily-by-market',
            headers=api._h('FHPTJ04040000'),
            params={'FID_COND_MRKT_DIV_CODE': 'U', 'FID_INPUT_ISCD': code, 'FID_INPUT_DATE_1': today,
                    'FID_INPUT_ISCD_1': mkt, 'FID_INPUT_DATE_2': today, 'FID_INPUT_ISCD_2': code},
        )
        d = r.json()
        print(f"\n[{label}] rt_cd={d.get('rt_cd')} msg1={d.get('msg1')}")
        for row in (d.get('output') or [])[:2]:
            print(f"  date={row.get('stck_bsop_date')} " + ' '.join(f'{k}={row.get(k)}' for k in _FIELDS))


if __name__ == '__main__':
    main()
