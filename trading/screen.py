"""
종목 스크리닝 — 진입 조건 사전 평가
GitHub Actions workflow_dispatch 또는 로컬에서 실행
결과를 카카오톡으로 수신
"""
import sys
from kis_api import KISApi
import kakao_notify
from strategy import _score_entry

# ── 스크리닝 후보 종목 (StockWiki 테마별 추천 전 종목) ────────────────────────
CANDIDATES = [
    # 피지컬 AI / 휴머노이드 로봇
    {'code': '108490', 'name': '로보티즈',       'sector': 'AI로봇'},
    {'code': '056080', 'name': '유진로봇',        'sector': 'AI로봇'},
    {'code': '466100', 'name': '클로봇',          'sector': 'AI로봇'},
    {'code': '022100', 'name': '포스코DX',        'sector': 'AI로봇'},
    {'code': '011070', 'name': 'LG이노텍',        'sector': 'AI로봇'},
    {'code': '307950', 'name': '현대오토에버',    'sector': 'AI로봇'},
    {'code': '066570', 'name': 'LG전자',          'sector': 'AI로봇'},
    # 전력설비
    {'code': '010120', 'name': 'LS ELECTRIC',    'sector': '전력설비'},
    {'code': '000500', 'name': '가온전선',        'sector': '전력설비'},
    {'code': '001440', 'name': '대한전선',        'sector': '전력설비'},
    {'code': '006260', 'name': 'LS',              'sector': '전력설비'},
    {'code': '034020', 'name': '두산에너빌리티',  'sector': '전력설비'},
    {'code': '103590', 'name': '일진전기',        'sector': '전력설비'},
    {'code': '229640', 'name': 'LS에코에너지',    'sector': '전력설비'},
    {'code': '060370', 'name': 'LS마린솔루션',    'sector': '전력설비'},
    # 반도체
    {'code': '005930', 'name': '삼성전자',        'sector': '반도체'},
    {'code': '000660', 'name': 'SK하이닉스',      'sector': '반도체'},
    {'code': '000990', 'name': 'DB하이텍',        'sector': '반도체'},
    # AI 챗봇
    {'code': '018260', 'name': '삼성에스디에스',  'sector': 'AI챗봇'},
    {'code': '035420', 'name': 'NAVER',           'sector': 'AI챗봇'},
    {'code': '007660', 'name': '이수페타시스',    'sector': 'AI챗봇'},
    {'code': '035720', 'name': '카카오',          'sector': 'AI챗봇'},
    # 조선
    {'code': '097230', 'name': 'HJ중공업',        'sector': '조선'},
    {'code': '010140', 'name': '삼성중공업',      'sector': '조선'},
    {'code': '042660', 'name': '한화오션',        'sector': '조선'},
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
