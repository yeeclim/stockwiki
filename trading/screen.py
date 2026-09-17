"""
종목 스크리닝 — 진입 조건 사전 평가
GitHub Actions 평일 06:30 / 15:00 KST 자동 실행 (스케줄 지연 가능)
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
import config_crypto
import subscriptions
from exclusions import get_excluded_codes

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()


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
        # 관리자가 제외한 종목은 사용자 추가분까지 통째로 뺀다 (메일·게시판·추천에 노출 금지)
        excluded = get_excluded_codes()
        rows = [row for row in rows if row['stock_code'] not in excluded]
        if excluded:
            print(f"🚫 관리자 제외 종목 {len(excluded)}개 건너뜀")
        # 중복 종목코드 제거 (같은 종목이 여러 유저에 의해 추가된 경우).
        # 시스템 종목과 겹치면 시스템 쪽을 남긴다 — source 가 결과 저장 범위를 가른다.
        by_code: dict[str, dict] = {}
        for row in rows:
            code = row['stock_code']
            is_system = row.get('source') == 'system' and not row.get('user_id')
            prev = by_code.get(code)
            if prev is None or (is_system and not prev['system']):
                by_code[code] = {
                    'code':   code,
                    'name':   row['stock_name'],
                    'sector': row['sector'],
                    'system': is_system,
                }
        result = list(by_code.values())
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
    # screening_results 는 자동매매 감시종목(main.py)과 전체 공개 추천 목록의 원천이다.
    # 사용자가 임의로 추가한 종목이 여기 들어가면 다른 모든 사용자의 자동매수 대상이
    # 될 수 있으므로 시스템 후보만 저장한다.
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
        for r in results if not r.get('error') and r.get('system')
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


def _archive_email(subject: str, html: str, plain_text: str, brief: dict | None = None):
    """실제 발송한 메일의 HTML/텍스트 원본을 그대로 저장 (블로그 등 다른 채널에서 재사용).
    brief(요약 지표 dict)도 함께 저장해 두면 로컬 블로그 스크립트가 요약 카드 이미지를 만들 때 쓴다.
    brief_json 컬럼이 아직 없으면(마이그레이션 전) 그 필드만 빼고 다시 저장한다."""
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        return

    payload = {'subject': subject, 'html': html, 'plain_text': plain_text}
    if brief is not None:
        payload['brief_json'] = brief

    def _post(body: dict):
        return requests.post(
            f"{_SUPABASE_URL}/rest/v1/email_archive",
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
                'Content-Type':  'application/json',
            },
            json=body,
            timeout=10,
        )

    try:
        r = _post(payload)
        if not r.ok and 'brief_json' in payload:
            print(f"⚠️  brief_json 포함 저장 실패({r.status_code}) — 해당 컬럼 없이 재시도합니다.")
            payload.pop('brief_json')
            r = _post(payload)
        if r.ok:
            print("🗄️  메일 원본 저장 완료")
        else:
            print(f"⚠️  메일 원본 저장 실패: {r.status_code} {r.text[:200]}")
    except Exception as e:
        print(f"⚠️  메일 원본 저장 오류: {e}")


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
                'system':     stock['system'],
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

    # 이메일에 들어가는 시장 신호/브리핑을 게시판 기록에도 동일하게 남기기 위해
    # 게시판 등록보다 먼저 계산해둔다.
    try:
        brief = us_market_brief.get_brief(api)
        print(f"🌙 미국시장 브리핑: 지수 {len(brief['indices'])}개, "
              f"섹터 {len(brief['sectors'])}개, 요약 {'있음' if brief['summary'] else '없음'}")
        print(f"🇰🇷 국내 마감 시황: 지수 {len(brief['kr_indices'])}개, "
              f"선물 미결제약정 {'있음' if brief['kr_open_interest'] else '없음'}, "
              f"투자자매매동향 {len(brief['kr_investors'])}개")
    except Exception as e:
        print(f"⚠️  미국시장 브리핑 생성 실패: {e}")
        brief = None

    # 오늘 신호 판정을 적중률 로그에 남긴다. 나중에 forecast_log.py report 로
    # "이 판정이 그냥 '항상 강세' 라고 찍는 것보다 나았나" 를 검증하기 위한 기록이다.
    # 실패해도 스크리닝 본 흐름에 영향을 주면 안 된다.
    try:
        import forecast_log
        forecast_log.record(brief)
        # 어제까지의 미기입 행에 실제 시가/종가를 채운다. 매일 도는 이 스크립트가
        # 채우기까지 겸하므로 별도 워크플로가 필요 없다.
        forecast_log.fill_outcomes()
    except Exception as e:
        print(f"⚠️  적중률 로그 기록 생략: {e}")

    # 게시판 히스토리 등록
    import board_post
    from datetime import datetime, timezone
    import pytz
    kst = pytz.timezone('Asia/Seoul')
    date_str = datetime.now(kst).strftime('%Y년 %m월 %d일 %H시')
    ok_count = sum(1 for r in results if r.get('pass'))
    bp_title = f"{date_str} 스크리닝 종목"
    bp_content = board_post.screening_content(
        results, date_str,
        signals=(brief.get('signals') if brief else None),
        excluded=excluded,
    )
    bp_id = board_post.post(bp_title, bp_content)
    if bp_id:
        print("📋 게시판 스크리닝 기록 등록 완료")
    else:
        print("⚠️  게시판 스크리닝 기록 등록 실패")

    # 카카오톡 "자세히 보기" 링크 — 게시글이 등록됐으면 해당 글로, 아니면 홈으로
    kakao_link = board_post.post_url(bp_id) if bp_id else None

    # 관리자: 카카오톡 (기존)
    kakao_notify.send(report, link_url=kakao_link)

    # 가입 유저: 카카오톡 (등록된 리프레시 토큰을 가진 사용자에 한해)
    # 발송 시각이 21~08시(KST)면 야간 수신 동의까지 있어야 보낸다 (정보통신망법 제50조)
    night = subscriptions.is_night_kst()

    def _fetch_user_kakao_tokens() -> list[str]:
        if not (_SUPABASE_URL and _SUPABASE_KEY):
            return []
        try:
            # 카카오 연동 자체가 알림 수신 의사 표시지만, 야간 발송은 별도 동의가 필요하다
            allowed = set(subscriptions.consented_rows(night)) if night else None
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
            # 토큰도 trading_configs 에 암호화 저장돼 있다 (config_crypto 참조).
            tokens = []
            for row in rows:
                raw = row.get('notify_kakao_refresh_token')
                if not raw:
                    continue
                if allowed is not None and row.get('user_id') not in allowed:
                    continue
                try:
                    tokens.append(config_crypto.decrypt(raw))
                except Exception as e:
                    print(f"⚠️  카카오 토큰 복호화 실패 (user_id={row.get('user_id')}): {e}")
            return tokens
        except Exception as e:
            print(f"⚠️  카카오 수신자 조회 실패: {e}")
            return []

    kakao_tokens = _fetch_user_kakao_tokens()
    if kakao_tokens:
        sent = kakao_notify.send_to_users(report, kakao_tokens, link_url=kakao_link)
        print(f"📱 카카오톡 발송 완료 → {sent}명 (시도 {len(kakao_tokens)}명)")
    else:
        print("⚠️  카카오톡 수신자 없음")

    # 메일 본문 (간밤 미국시장 브리핑을 상단에 포함한 HTML)
    if brief:
        html = us_market_brief.render_email_html(brief, report)
        brief_text = us_market_brief.render_text(brief)
        plain = f"{brief_text}\n\n{report}" if brief_text else report
        # 블로그 등 다른 채널용 원본 — 수신자 수와 무관하게 보관한다
        # (동의자가 0명인 날에도 기록이 끊기지 않도록)
        _archive_email(bp_title, html, plain, brief)
    else:
        from html import escape
        html = f"<html><body><pre style='font-family:inherit;white-space:pre-wrap'>{escape(report)}</pre></body></html>"
        plain = report

    # 수신 동의한 사용자에게만 이메일 발송
    try:
        recipients = subscriptions.email_recipients(night)
    except Exception as e:
        # 동의 여부를 확인할 수 없으면 보내지 않는다
        print(f"⚠️  수신 동의 조회 실패 — 이메일 발송 생략: {e}")
        recipients = []
    if not recipients:
        print(f"⚠️  이메일 수신 동의자 없음 ({'야간 동의 필요' if night else '주간 발송'})")
        return False
    sent, tried = email_notify.send_newsletter(html, plain, recipients)
    return sent > 0


if __name__ == '__main__':
    screen()
