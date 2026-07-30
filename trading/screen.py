"""
종목 스크리닝 — 진입 조건 사전 평가
GitHub Actions 매일 장 시작 전(08:50 KST) 자동 실행
결과를 카카오톡(관리자) + 이메일(가입 유저 전체) 발송
"""
import os
import sys
import time
from urllib.parse import quote
import requests
from kis_api import KISApi
import kakao_notify
import email_notify
import us_market_brief
from strategy import _score_entry
from news_sentiment import get_sentiment

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

BUY_THRESHOLD = 6

# KIS API·뉴스 감성 분석이 느려질 때(응답은 오지만 지연) 워크플로 타임아웃 전에
# 나머지 단계(게시판/카카오/브리핑/이메일 발송)를 위한 여유 시간을 확보하기 위한 예산.
# 각 단계는 예산을 넘기면 남은 종목을 건너뛰고 지금까지의 결과로 계속 진행한다.
_FETCH_BUDGET_SEC = 360       # KIS 종목별 조회 루프
_SENTIMENT_BUDGET_SEC = 240   # 뉴스 감성 분석 루프


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


def _save_results(results: list[dict]):
    """스크리닝 결과를 Supabase screening_results 테이블에 upsert"""
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        return
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    rows = [
        {
            'stock_code':  r['code'],
            'stock_name':  r['name'],
            'sector':      r.get('sector', ''),
            'score':       r.get('score', 0),
            'price':       r.get('price'),
            'market_cap':  r.get('market_cap', 0),
            'pass':        r.get('pass', False),
            'screened_at': now,
        }
        for r in results if not r.get('error')
    ]
    if not rows:
        return
    try:
        resp = requests.post(
            f"{_SUPABASE_URL}/rest/v1/screening_results",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
                'Content-Type':  'application/json',
                'Prefer':        'resolution=merge-duplicates',
            },
            json=rows,
            timeout=10,
        )
        if resp.ok:
            print(f"💾 스크리닝 결과 {len(rows)}개 저장 완료")
        else:
            print(f"⚠️  스크리닝 결과 저장 실패: {resp.status_code} {resp.text[:200]}")
    except Exception as e:
        print(f"⚠️  스크리닝 결과 저장 오류: {e}")


def screen():
    api = KISApi()
    try:
        api.auth()
    except Exception as e:
        print(f"⚠️ KIS API 인증 실패: {e}")
        # 관리자에게 간단 알림 전송 시도
        try:
            kakao_notify.send(f"[오류] 종목 스크리닝 중 KIS API 인증 실패: {e}")
        except Exception:
            pass
        return False

    candidates = _fetch_candidates()
    if not candidates:
        print("⚠️  후보 종목 없음 — 스크리닝 종료")
        return []

    results = []

    fetch_start = time.monotonic()
    for i, stock in enumerate(candidates):
        if time.monotonic() - fetch_start > _FETCH_BUDGET_SEC:
            print(f"⏱️  종목 조회 시간 예산({_FETCH_BUDGET_SEC}s) 초과 — "
                  f"나머지 {len(candidates) - i}종목은 이번 실행에서 건너뜀")
            break
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
                'code':       code,
                'name':       name,
                'sector':     sector,
                'price':      price,
                'ma60':       ma60,
                'ma5':        ma5,
                'ma20':       ma20,
                'per':        fund.get('per', 0),
                'pbr':        fund.get('pbr', 0),
                'volume':     fund.get('volume', 0),
                'market_cap': fund.get('market_cap', 0),
                'prdy_ctrt':  prdy_ctrt,
                'score':      score,
                'max_score':  max_score,
                'discount':   discount,
                'ratios':     ratios or {},
                'pass':       score >= BUY_THRESHOLD,
            })
        except Exception as e:
            print(f"⚠️  {name} ({code}) 조회 실패: {e}")
            results.append({
                'code': code, 'name': name, 'sector': sector,
                'error': str(e)
            })

    # ── 뉴스 감성 게이트 ──────────────────────────────────────────────────────
    # 점수 통과 종목이라도 최근 뉴스 감성이 "부정"이면 최종 탈락시킨다.
    # (뉴스 없음/분석 실패는 배제 사유로 보지 않음)
    sentiment_start = time.monotonic()
    sentiment_budget_exceeded = False
    for r in results:
        if r.get('pass') and not r.get('error'):
            if not sentiment_budget_exceeded and \
                    time.monotonic() - sentiment_start > _SENTIMENT_BUDGET_SEC:
                sentiment_budget_exceeded = True
                print(f"⏱️  뉴스 감성 분석 시간 예산({_SENTIMENT_BUDGET_SEC}s) 초과 — "
                      "나머지 종목은 감성 분석 없이 통과 처리")
            if sentiment_budget_exceeded:
                r['sentiment'] = None
                r['sentiment_line'] = '시간 초과로 미분석'
                continue
            sentiment, sentiment_line = get_sentiment(r['code'], r['name'])
            r['sentiment'] = sentiment
            r['sentiment_line'] = sentiment_line
            if sentiment == '부정':
                r['pass'] = False
                r['sentiment_excluded'] = True

    # ── 결과 출력 ──────────────────────────────────────────────────────────────
    sep = "=" * 55
    lines = [f"\n{sep}", "  📊 종목 스크리닝 결과", sep]

    # 점수 높은 순 정렬
    ok       = [r for r in results if r.get('pass') and not r.get('error')]
    excluded = [r for r in results if r.get('sentiment_excluded')]
    others   = [r for r in results if not r.get('pass') and not r.get('error') and not r.get('sentiment_excluded')]
    errors   = [r for r in results if r.get('error')]

    ok.sort(key=lambda x: x['score'], reverse=True)
    excluded.sort(key=lambda x: x['score'], reverse=True)
    others.sort(key=lambda x: x.get('score', 0), reverse=True)

    def chart_url(code, name):
        return f"https://stockwiki.vercel.app/?stock={code}&name={quote(name)}"

    def _ratio_str(r):
        ratios = r.get('ratios') or {}
        parts = []
        if '부채비율'  in ratios: parts.append(f"부채{ratios['부채비율']:.0f}%")
        if '유동비율'  in ratios: parts.append(f"유동{ratios['유동비율']:.0f}%")
        if '현금비율'  in ratios: parts.append(f"현금{ratios['현금비율']:.0f}%")
        if '이자보상배율' in ratios: parts.append(f"이자보상{ratios['이자보상배율']:.0f}%")
        return f"  {' '.join(parts)}" if parts else ""

    if ok:
        lines.append(f"\n✅ 주목 종목 ({BUY_THRESHOLD}점 이상 + 뉴스 감성 양호, {len(ok)}개)")
        for r in ok:
            disc = f"  MA60대비 -{r['discount']:.1f}%" if r['discount'] else ""
            mcap = r.get('market_cap', 0)
            mcap_str = f"  시총 {mcap:,}억" if mcap else ""
            lines.append(
                f"  [{r['score']}/{r['max_score']}점] {r['name']}({r['code']})  {r['price']:,}원"
                f"  PER {r['per']:.1f} PBR {r['pbr']:.2f}"
                f"  전일{r['prdy_ctrt']:+.1f}%{disc}{mcap_str}{_ratio_str(r)}"
                f"  [{r['sector']}]"
                f"\n  📰 뉴스: {r['sentiment_line']}"
                f"\n  📊 {chart_url(r['code'], r['name'])}"
            )
    else:
        lines.append(f"\n⏸  {BUY_THRESHOLD}점 이상 + 뉴스 감성 양호 종목 없음")

    if excluded:
        lines.append(f"\n🔴 뉴스 부정으로 제외 ({len(excluded)}개) — 진입 점수는 통과했으나 최근 뉴스가 부정적")
        for r in excluded:
            lines.append(
                f"  [{r['score']}/{r['max_score']}점] {r['name']}({r['code']})  {r['price']:,}원"
                f"\n  📰 뉴스: {r['sentiment_line']}"
            )

    if errors:
        lines.append(f"\n❌ 조회 실패")
        for r in errors:
            lines.append(f"  {r['name']}({r['code']}): {r['error']}")

    lines.append(f"\n{sep}")

    report = "\n".join(lines)
    print(report)

    # 스크리닝 결과 Supabase 저장 (main.py watchlist 자동 연동용)
    _save_results(results)

    # 게시판 히스토리 등록
    import board_post
    from datetime import datetime, timezone
    import pytz
    kst = pytz.timezone('Asia/Seoul')
    date_str = datetime.now(kst).strftime('%Y년 %m월 %d일 %H시')
    ok_count = sum(1 for r in results if r.get('pass'))
    bp_title = f"{date_str} 스크리닝 종목"
    bp_content = board_post.screening_content(results, date_str)
    if board_post.post(bp_title, bp_content):
        print("📋 게시판 스크리닝 기록 등록 완료")
    else:
        print("⚠️  게시판 스크리닝 기록 등록 실패")

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

    # 가입 유저 전체: 이메일 (간밤 미국시장 브리핑을 상단에 포함한 HTML)
    try:
        brief = us_market_brief.get_brief()
        print(f"🌙 미국시장 브리핑: 지수 {len(brief['indices'])}개, "
              f"섹터 {len(brief['sectors'])}개, 요약 {'있음' if brief['summary'] else '없음'}")
    except Exception as e:
        print(f"⚠️  미국시장 브리핑 생성 실패: {e}")
        brief = None

    recipients = _fetch_user_emails()
    if recipients:
        if brief:
            html = us_market_brief.render_email_html(brief, report)
            brief_text = us_market_brief.render_text(brief)
            plain = f"{brief_text}\n\n{report}" if brief_text else report
            ok = email_notify.send_html_to(html, plain, recipients)
        else:
            ok = email_notify.send_to(report, recipients)
        if ok:
            print(f"📧 이메일 발송 완료 → {len(recipients)}명")
        else:
            print("⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 환경변수 확인)")
    else:
        print("⚠️  이메일 수신자 없음")

    return ok


if __name__ == '__main__':
    screen()
