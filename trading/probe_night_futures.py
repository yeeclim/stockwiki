"""KIS 야간선물 시세 조회 경로 탐색 — 수동 실행 전용(probe_night_futures.yml).

배경
----
KRX 야간선물은 2025년 6월부터 자체운영 체계로 전환됐고, KIS 마스터파일
fo_cme_code.mst 에 코스피200 야간선물 종목코드가 계속 올라온다. 그런데 KIS 공식
예제에 문서화된 FID_COND_MRKT_DIV_CODE 는 F(지수선물)·O(지수옵션)·JF(주식선물)
뿐이고, 야간 전용 값은 공개 문서에서 확인되지 않는다. KIS 의 ngt 계열 엔드포인트는
전부 /trading/ (주문·잔고·증거금) 이라 시세용이 없다.

그래서 후보 코드를 실계좌로 하나씩 찔러보고 어떤 조합이 응답하는지 기록한다.

이 스크립트는 조회만 한다 — 주문도, 메일 발송도, DB 쓰기도 없다.
결과를 보고 되는 조합을 us_market_brief 의 '야간 한국물' 신호에 붙인다.

실행: GitHub Actions > "KIS 야간선물 탐색" > Run workflow
"""
import json
import os
import sys
from datetime import datetime

import pytz

import kr_market_data as kmd
from kis_api import KISApi

# FID_COND_MRKT_DIV_CODE 후보. F 는 대조군(주간 지수선물, 확실히 동작).
_MARKET_CODES = ['F', 'CM', 'CF', 'NF', 'N', 'FN', 'JF']

# tr_id 후보. FHMIF10000000 은 현재 미결제약정 조회에 쓰는 값(대조군).
_TR_IDS = ['FHMIF10000000', 'FHMCF10000000', 'FHMNF10000000']

_ENDPOINT = '/uapi/domestic-futureoption/v1/quotations/inquire-price'

# 응답에서 시세로 쓸 만한 필드 후보 (현재가 / 전일대비율)
_PRICE_KEYS = ('futs_prpr', 'prpr', 'stck_prpr', 'ovrs_prpr')
_RATE_KEYS = ('prdy_ctrt', 'futs_prdy_ctrt', 'prdy_vrss_sign')


def _merged_output(d: dict) -> dict:
    """KIS 응답의 output/output1/output2/output3 을 하나로 합친다."""
    merged: dict = {}
    for key in ('output', 'output1', 'output2', 'output3'):
        section = d.get(key)
        if isinstance(section, dict):
            merged.update(section)
        elif isinstance(section, list) and section and isinstance(section[0], dict):
            merged.update(section[0])
    return merged


def probe(api: KISApi, code: str, mrkt: str, tr_id: str) -> dict:
    try:
        r = api._get(
            _ENDPOINT,
            headers=api._h(tr_id),
            params={'FID_COND_MRKT_DIV_CODE': mrkt, 'FID_INPUT_ISCD': code},
        )
        body = r.json()
    except Exception as e:
        return {'ok': False, 'err': f'{type(e).__name__}: {e}'}

    rt = body.get('rt_cd')
    if rt != '0':
        return {'ok': False, 'rt_cd': rt, 'msg': (body.get('msg1') or '').strip()}

    merged = _merged_output(body)
    price = next((merged[k] for k in _PRICE_KEYS if merged.get(k)), None)
    rate = next((merged[k] for k in _RATE_KEYS if merged.get(k)), None)
    return {
        'ok': True,
        'price': price,
        'rate': rate,
        'field_count': len(merged),
        # 되는 조합이 나오면 어떤 필드를 읽어야 할지 판단해야 하므로 키를 남긴다.
        'keys': sorted(merged)[:40],
    }


def main() -> int:
    kst = pytz.timezone('Asia/Seoul')
    now = datetime.now(kst)
    code = kmd.kospi200_futures_code()
    print(f'실행 시각 : {now:%Y-%m-%d %a %H:%M KST}')
    print(f'최근월물   : {code}')
    print('야간시장 운영 시간은 18:00~05:00 KST — 그 시간대에 돌려야 살아있는 값이 나온다.')
    print('=' * 78)

    try:
        api = KISApi()
        api.auth()
    except Exception as e:
        print(f'❌ KIS 인증 실패: {e}')
        return 1

    hits = []
    for tr_id in _TR_IDS:
        for mrkt in _MARKET_CODES:
            res = probe(api, code, mrkt, tr_id)
            tag = f'{tr_id} / MRKT={mrkt:<3}'
            if res.get('ok'):
                print(f'✅ {tag} → price={res["price"]} rate={res["rate"]} '
                      f'fields={res["field_count"]}')
                hits.append({'tr_id': tr_id, 'mrkt': mrkt, **res})
            else:
                detail = res.get('err') or f'rt_cd={res.get("rt_cd")} {res.get("msg")}'
                print(f'   {tag} → {detail}')

    print('=' * 78)
    if not hits:
        print('되는 조합 없음. 야간시장 시간대(18:00~05:00 KST)에 다시 돌려볼 것.')
        return 0

    print(f'응답한 조합 {len(hits)}개:')
    for h in hits:
        print(f'  - {h["tr_id"]} / {h["mrkt"]} : price={h["price"]} rate={h["rate"]}')
    print()
    print('첫 조합의 응답 필드:')
    print(json.dumps(hits[0]['keys'], ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
