"""
종목 스크리닝 — 진입 조건 사전 평가
GitHub Actions workflow_dispatch 또는 로컬에서 실행
결과를 카카오톡으로 수신
"""
import sys
from kis_api import KISApi
import kakao_notify
from strategy import _score_entry

# ── 스크리닝 후보 종목 ────────────────────────────────────────────────────────
CANDIDATES = [
    # 방산
    {'code': '012450', 'name': '한화에어로스페이스', 'sector': '방산'},
    {'code': '079550', 'name': 'LIG넥스원',          'sector': '방산'},
    {'code': '047810', 'name': '한국항공우주',        'sector': '방산'},
    {'code': '064350', 'name': '현대로템',            'sector': '방산'},
    {'code': '272210', 'name': '한화시스템',          'sector': '방산'},
    # 전기/전력
    {'code': '015760', 'name': '한국전력',            'sector': '전기'},
    {'code': '051600', 'name': '한전KPS',             'sector': '전기'},
    {'code': '052690', 'name': '한전기술',            'sector': '전기'},
    {'code': '001440', 'name': '대한전선',            'sector': '전기'},
    {'code': '103590', 'name': '일진전기',            'sector': '전기'},
    # 반도체 (장비/소재)
    {'code': '042700', 'name': '한미반도체',          'sector': '반도체'},
    {'code': '240810', 'name': '원익IPS',             'sector': '반도체'},
    {'code': '058470', 'name': '리노공업',            'sector': '반도체'},
    {'code': '095610', 'name': '테스',                'sector': '반도체'},
    {'code': '000990', 'name': 'DB하이텍',            'sector': '반도체'},
    {'code': '005930', 'name': '삼성전자',            'sector': '반도체'},
    # 로봇
    {'code': '348370', 'name': '뉴로메카',            'sector': '로봇'},
    {'code': '117730', 'name': '티로보틱스',          'sector': '로봇'},
    {'code': '056080', 'name': '유진로봇',            'sector': '로봇'},
    {'code': '090360', 'name': '로보스타',            'sector': '로봇'},
    {'code': '466100', 'name': '클로봇',              'sector': '로봇'},
    # AI
    {'code': '036570', 'name': '엔씨소프트',          'sector': 'AI'},
    {'code': '035420', 'name': 'NAVER',               'sector': 'AI'},
    {'code': '035720', 'name': '카카오',              'sector': 'AI'},
    {'code': '304100', 'name': '솔트룩스',            'sector': 'AI'},
    {'code': '315640', 'name': '딥노이드',            'sector': 'AI'},
]

BUY_THRESHOLD = 6


def screen():
    api = KISApi()
    api.auth()

    results = []

    for stock in CANDIDATES:
        code = stock['code']
        name = stock['name']
        sector = stock['sector']
        try:
            fund    = api.get_fundamentals(code)
            ma_data = api.get_ma_data(code)
            ratios  = api.get_financial_ratios(code)

            price  = fund['price']
            ma60   = ma_data.get('ma60')
            ma5    = ma_data.get('ma5')
            ma20   = ma_data.get('ma20')
            prdy_ctrt = fund.get('prdy_ctrt', 0.0)

            score, max_score, _ = _score_entry(fund, ma_data, ratios)

            # MA60 대비 할인율
            discount = (ma60 - price) / ma60 * 100 if ma60 else None

            results.append({
                'code':    code,
                'name':    name,
                'sector':  sector,
                'price':   price,
                'ma60':    ma60,
                'ma5':     ma5,
                'ma20':    ma20,
                'per':     fund.get('per', 0),
                'pbr':     fund.get('pbr', 0),
                'volume':  fund.get('volume', 0),
                'prdy_ctrt': prdy_ctrt,
                'score':   score,
                'discount': discount,
                'pass':    score >= BUY_THRESHOLD,
            })
        except Exception as e:
            print(f"⚠️  {name} ({code}) 조회 실패: {e}")
            results.append({
                'code': code, 'name': name, 'sector': sector,
                'error': str(e)
            })

    # ── 결과 출력 ──────────────────────────────────────────────────────────────
    sep = "=" * 55
    lines = [f"\n{sep}", "  📊 종목 스크리닝 결과", sep]

    # 점수 높은 순 정렬
    ok     = [r for r in results if r.get('pass') and not r.get('error')]
    others = [r for r in results if not r.get('pass') and not r.get('error')]
    errors = [r for r in results if r.get('error')]

    ok.sort(key=lambda x: x['score'], reverse=True)
    others.sort(key=lambda x: x.get('score', 0), reverse=True)

    if ok:
        lines.append(f"\n✅ 진입 가능 종목 ({BUY_THRESHOLD}점 이상)")
        for r in ok:
            disc = f"  MA60대비 -{r['discount']:.1f}%" if r['discount'] else ""
            lines.append(
                f"  [{r['score']}/{r['max_score'] if 'max_score' in r else 10}점] "
                f"{r['name']}({r['code']})  {r['price']:,}원"
                f"  PER {r['per']:.1f} PBR {r['pbr']:.2f}"
                f"  전일{r['prdy_ctrt']:+.1f}%{disc}"
                f"  [{r['sector']}]"
            )

    lines.append(f"\n⏸  조건 미달")
    for r in others:
        ma60_str = f"MA60 {r['ma60']:,.0f}원" if r.get('ma60') else "MA60 없음"
        above = "위" if r.get('ma60') and r.get('price', 0) >= r['ma60'] else "아래"
        lines.append(
            f"  [{r.get('score',0)}/10점] {r['name']}({r['code']})  "
            f"{r.get('price',0):,}원  {ma60_str} {above}  [{r['sector']}]"
        )

    if errors:
        lines.append(f"\n❌ 조회 실패")
        for r in errors:
            lines.append(f"  {r['name']}({r['code']}): {r['error']}")

    lines.append(f"\n{sep}")

    report = "\n".join(lines)
    print(report)
    kakao_notify.send(report)

    return ok


if __name__ == '__main__':
    ok = screen()
    if not ok:
        print("\n진입 가능 종목 없음 — WATCHLIST 변경 불필요")
        sys.exit(0)
    else:
        print(f"\n👆 위 종목을 trading/main.py WATCHLIST에 추가하세요.")
