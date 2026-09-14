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


def _session_label(now: datetime) -> str:
    """실행 시각이 야간장의 어느 국면인가."""
    hm = now.hour * 60 + now.minute
    if hm >= 18 * 60 or hm < 5 * 60:
        return '야간장 진행 중'
    if hm < 9 * 60:
        return '야간장 마감 후 / 정규장 개장 전 — 종가가 남아있는지 보는 게 핵심'
    if hm < 15 * 60 + 30:
        return '정규장 진행 중'
    return '정규장 마감 후 / 야간장 개장 전'


def main() -> int:
    kst = pytz.timezone('Asia/Seoul')
    now = datetime.now(kst)
    code = kmd.kospi200_futures_code()
    print(f'실행 시각 : {now:%Y-%m-%d %a %H:%M KST}  ({_session_label(now)})')
    print(f'최근월물   : {code}')

    # 대조군: 네이버가 주는 정규장 선물. 후보 조합이 이 값을 그대로 돌려주면
    # 야간 시세가 아니라 정규장 데이터를 재탕하는 것이라 쓸모가 없다.
    day_price = day_pct = None
    try:
        fut = kmd.get_quotes().get('FUT')
        if fut:
            day_price, day_pct = fut['price'], fut['pct']
            print(f'정규장 선물 : {day_price} ({day_pct:+.2f}%)  ← 대조군')
    except Exception as e:
        print(f'정규장 선물 조회 실패(비교 생략): {e}')
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
                verdict = ''
                if day_price is not None and res['price'] is not None:
                    try:
                        same = abs(float(res['price']) - float(day_price)) < 1e-9
                        verdict = ('  ⚠️ 정규장과 동일값(야간 시세 아님)' if same
                                   else '  ⭐ 정규장과 다름 — 야간 시세 후보')
                    except (TypeError, ValueError):
                        pass
                print(f'✅ {tag} → price={res["price"]} rate={res["rate"]} '
                      f'fields={res["field_count"]}{verdict}')
                hits.append({'tr_id': tr_id, 'mrkt': mrkt, 'verdict': verdict.strip(), **res})
            else:
                detail = res.get('err') or f'rt_cd={res.get("rt_cd")} {res.get("msg")}'
                print(f'   {tag} → {detail}')

    print('=' * 78)
    if not hits:
        print('되는 조합 없음. 야간시장 시간대(18:00~05:00 KST)에 다시 돌려볼 것.')
        return 0

    print(f'응답한 조합 {len(hits)}개:')
    for h in hits:
        print(f'  - {h["tr_id"]} / {h["mrkt"]} : price={h["price"]} rate={h["rate"]} '
              f'{h.get("verdict", "")}')

    winners = [h for h in hits if '⭐' in h.get('verdict', '')]
    print()
    if winners:
        w = winners[0]
        print(f'>>> 야간 시세로 쓸 조합: FID_COND_MRKT_DIV_CODE={w["mrkt"]}, '
              f'tr_id={w["tr_id"]}')
        print('    kis_api.KISApi.NIGHT_MARKET_CODES 를 이 순서로 고칠 것.')
        print()
        print('응답 필드:')
        print(json.dumps(w['keys'], ensure_ascii=False, indent=2))
    else:
        print('>>> 응답은 있으나 전부 정규장과 같은 값 — 야간 시세 경로는 아직 못 찾음.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
