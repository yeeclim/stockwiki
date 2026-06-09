"""
종목 스크리닝 — 진입 조건 사전 평가
GitHub Actions 매일 장 시작 전(08:50 KST) 자동 실행
결과를 카카오톡(관리자) + 이메일(가입 유저 전체) 발송
"""
import os
import sys
import requests
from kis_api import KISApi
import kakao_notify
import email_notify
from strategy import _score_entry

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()


def _fetch_user_emails() -> list[str]:
    """가입한 모든 유저 이메일 조회 (API 키 등록 여부 무관)"""
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        return []
    try:
        r = requests.get(
            f"{_SUPABASE_URL}/auth/v1/admin/users?per_page=1000",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
            },
            timeout=10,
        )
        r.raise_for_status()
        users = r.json().get('users', [])
        return [u['email'] for u in users if u.get('email')]
    except Exception as e:
        print(f"⚠️  유저 이메일 조회 실패: {e}")
        return []

BUY_THRESHOLD = 5


def _fetch_candidates() -> list[dict]:
    """Supabase에서 활성 스크리닝 후보 조회 (시스템 + 전체 유저 추가 종목)"""
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        return []
    try:
        r = requests.get(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates"
            "?is_active=eq.true&order=sector,stock_code",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
            },
            timeout=10,
        )
        r.raise_for_status()
        rows = r.json()
        # 중복 종목코드 제거 (같은 종목이 여러 유저에 의해 추가된 경우)
        seen = set()
        result = []
        for row in rows:
            code = row['stock_code']
            if code not in seen:
                seen.add(code)
                result.append({
                    'code':   code,
                    'name':   row['stock_name'],
                    'sector': row['sector'],
                })
        print(f"📋 스크리닝 대상 {len(result)}종목 로드 완료")
        return result
    except Exception as e:
        print(f"⚠️  후보 종목 조회 실패: {e}")
        return []


def screen():
    api = KISApi()
    api.auth()

    candidates = _fetch_candidates()
    if not candidates:
        print("⚠️  후보 종목 없음 — 스크리닝 종료")
        return []

    results = []

    for stock in candidates:
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

    def chart_url(code):
        return f"https://m.finance.naver.com/item/main.naver?code={code}"

    if ok:
        lines.append(f"\n✅ 주목 종목 ({BUY_THRESHOLD}점 이상, {len(ok)}개)")
        for r in ok:
            disc = f"  MA60대비 -{r['discount']:.1f}%" if r['discount'] else ""
            lines.append(
                f"  [{r['score']}/10점] {r['name']}({r['code']})  {r['price']:,}원"
                f"  PER {r['per']:.1f} PBR {r['pbr']:.2f}"
                f"  전일{r['prdy_ctrt']:+.1f}%{disc}"
                f"  [{r['sector']}]"
                f"\n  📊 {chart_url(r['code'])}"
            )
    else:
        lines.append(f"\n⏸  {BUY_THRESHOLD}점 이상 종목 없음")

    if errors:
        lines.append(f"\n❌ 조회 실패")
        for r in errors:
            lines.append(f"  {r['name']}({r['code']}): {r['error']}")

    lines.append(f"\n{sep}")

    report = "\n".join(lines)
    print(report)

    # 관리자: 카카오톡 (기존)
    kakao_notify.send(report)

    # 가입 유저: 카카오톡 (등록된 리프레시 토큰을 가진 사용자에 한해)
    def _fetch_user_kakao_tokens() -> list[str]:
        if not (_SUPABASE_URL and _SUPABASE_KEY):
            return []
        try:
            r = requests.get(
                f"{_SUPABASE_URL}/rest/v1/trading_configs?is_active=eq.true",
                headers={
                    'apikey':        _SUPABASE_KEY,
                    'Authorization': f'Bearer {_SUPABASE_KEY}',
                },
                timeout=10,
            )
            r.raise_for_status()
            rows = r.json()
            return [row.get('notify_kakao_refresh_token') for row in rows if row.get('notify_kakao_refresh_token')]
        except Exception as e:
            print(f"⚠️  카카오 수신자 조회 실패: {e}")
            return []

    kakao_tokens = _fetch_user_kakao_tokens()
    if kakao_tokens:
        sent = kakao_notify.send_to_users(report, kakao_tokens)
        print(f"📱 카카오톡 발송 완료 → {sent}명 (시도 {len(kakao_tokens)}명)")
    else:
        print("⚠️  카카오톡 수신자 없음")

    # 가입 유저 전체: 이메일 (기존 동작)
    recipients = _fetch_user_emails()
    if recipients:
        ok = email_notify.send_to(report, recipients)
        if ok:
            print(f"📧 이메일 발송 완료 → {len(recipients)}명")
        else:
            print("⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 환경변수 확인)")
    else:
        print("⚠️  이메일 수신자 없음")

    return ok


if __name__ == '__main__':
    ok = screen()
    if not ok:
        print("\n진입 가능 종목 없음 — WATCHLIST 변경 불필요")
        sys.exit(0)
    else:
        print(f"\n👆 위 종목을 trading/main.py WATCHLIST에 추가하세요.")
