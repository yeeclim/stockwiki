"""장전(08:30~08:50) 국내 시세 원본 확인 — 수동/cron 실행 전용(probe_preopen_kr.yml).

08:35 발송 메일에 쓸 수 있는 국내 장전 정보가 실제로 어떤 필드로 내려오는지 본다.
  - 코스피200 선물 장전 동시호가 예상체결가 (정규 08:45 개장 전)
  - 현물 장전 동시호가(08:30~) 예상체결가 — 대형주(삼성전자·SK하이닉스)
  - NXT 프리마켓(08:00~08:50) 체결가
  - 네이버 실시간 API 가 장전에 무엇을 주는가 (overMarketPriceInfo 등)

이 스크립트는 조회만 한다 — 주문도, 메일 발송도, DB 쓰기도 없다.
"""
import json
from datetime import datetime

import pytz
import requests

import kr_market_data as kmd
from kis_api import KISApi

_UA = {'User-Agent': 'Mozilla/5.0'}

_NAVER = [
    ('네이버 지수·선물', 'https://polling.finance.naver.com/api/realtime/domestic/index/KOSPI,KOSDAQ,FUT'),
    ('네이버 삼성전자', 'https://polling.finance.naver.com/api/realtime/domestic/stock/005930'),
    ('네이버 SK하이닉스', 'https://polling.finance.naver.com/api/realtime/domestic/stock/000660'),
]

# (설명, 경로, tr_id, params)
_KIS = [
    ('KIS 지수선물 시세', '/uapi/domestic-futureoption/v1/quotations/inquire-price', 'FHMIF10000000',
     {'FID_COND_MRKT_DIV_CODE': 'F', 'FID_INPUT_ISCD': '{fut}'}),
    ('KIS 업종지수 코스피', '/uapi/domestic-stock/v1/quotations/inquire-index-price', 'FHPUP02100000',
     {'FID_COND_MRKT_DIV_CODE': 'U', 'FID_INPUT_ISCD': '0001'}),
]
for _code in ('005930', '000660'):
    for _mrkt in ('J', 'NX', 'UN'):
        _KIS.append((f'KIS 현재가 {_code} MRKT={_mrkt}', '/uapi/domestic-stock/v1/quotations/inquire-price',
                     'FHKST01010100', {'FID_COND_MRKT_DIV_CODE': _mrkt, 'FID_INPUT_ISCD': _code}))
    _KIS.append((f'KIS 호가·예상체결 {_code}', '/uapi/domestic-stock/v1/quotations/inquire-asking-price-exp-ccn',
                 'FHKST01010200', {'FID_COND_MRKT_DIV_CODE': 'J', 'FID_INPUT_ISCD': _code}))


def _nonempty(d) -> dict:
    """값이 비었거나 0 인 필드는 빼고 보여준다 — 장전에 실제로 채워진 필드를 찾는 게 목적."""
    if isinstance(d, list):
        d = d[0] if d and isinstance(d[0], dict) else {}
    if not isinstance(d, dict):
        return {}

    return {k: v for k, v in d.items() if v not in (None, '', '0', '0.00', 0)}


def main() -> int:
    now = datetime.now(pytz.timezone('Asia/Seoul'))
    print(f'실행 시각: {now:%Y-%m-%d %a %H:%M:%S KST}')
    print('=' * 78)

    for name, url in _NAVER:
        try:
            body = requests.get(url, headers=_UA, timeout=8).json()
            for item in body.get('datas', []):
                print(f'[{name}] {json.dumps(item, ensure_ascii=False)}')
        except Exception as e:
            print(f'[{name}] 실패: {e}')
    print('=' * 78)

    api = KISApi()
    api.auth()
    fut = kmd.kospi200_futures_code()
    for name, path, tr_id, params in _KIS:
        params = {k: v.format(fut=fut) for k, v in params.items()}
        try:
            body = api._get(path, headers=api._h(tr_id), params=params).json()
        except Exception as e:
            print(f'[{name}] 실패: {e}')
            continue

        if body.get('rt_cd') != '0':
            print(f"[{name}] rt_cd={body.get('rt_cd')} {body.get('msg1')}")
            continue

        for key in ('output', 'output1', 'output2', 'output3'):
            if key in body:
                print(f'[{name}] {key}: {json.dumps(_nonempty(body[key]), ensure_ascii=False)}')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
