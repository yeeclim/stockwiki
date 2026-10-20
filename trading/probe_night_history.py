"""야간선물 일봉 과거치 조회 가능 여부 확인 — 수동 실행 전용(probe_night_history.yml).

코스피200 야간선물이 시가 갭을 얼마나 맞히는지 검증하려면 수년치 일봉이 필요하다.
KIS 선물옵션 기간별시세(FHKIF03020100)에 야간 시장 코드를 넣으면 과거 일봉이 오는지,
소멸한 월물도 조회되는지 본다. 정규장('F')을 대조군으로 함께 찍는다.

조회만 한다 — 주문·메일·DB 쓰기 없음.
"""
import json

from kis_api import KISApi

_PATH = '/uapi/domestic-futureoption/v1/quotations/inquire-daily-fuopchartprice'
_MARKETS = ('F', 'CM', 'CF', 'NF')
_CONTRACTS = ('A01612', 'A01609', 'A01603', 'A01512', 'A01412')


def main() -> int:
    api = KISApi()
    api.auth()
    for mrkt in _MARKETS:
        for code in _CONTRACTS:
            params = {
                'FID_COND_MRKT_DIV_CODE': mrkt, 'FID_INPUT_ISCD': code,
                'FID_INPUT_DATE_1': '20200101', 'FID_INPUT_DATE_2': '20261020',
                'FID_PERIOD_DIV_CODE': 'D',
            }
            try:
                body = api._get(_PATH, headers=api._h('FHKIF03020100'), params=params).json()
            except Exception as e:
                print(f'[{mrkt} {code}] 실패: {e}')
                continue

            if body.get('rt_cd') != '0':
                print(f"[{mrkt} {code}] rt_cd={body.get('rt_cd')} {body.get('msg1')}")
                continue

            rows = [r for r in (body.get('output2') or []) if any(v not in ('', '0', None) for v in r.values())]
            print(f'[{mrkt} {code}] 행 {len(rows)}  output1={json.dumps(body.get("output1"), ensure_ascii=False)[:300]}')
            for r in rows[:3] + rows[-2:]:
                print(f'    {json.dumps(r, ensure_ascii=False)}')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
