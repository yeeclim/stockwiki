"""게시판 자동 게시글 등록 — 스크리닝/매수 히스토리"""
import hashlib
import os
import requests

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
_NICK = 'StockWiki'

# JS board.js 해시 방식과 동일: sha256(str + salt)
_PW_HASH = hashlib.sha256(('stockwiki_auto' + 'sw_pw').encode()).hexdigest()
_IP_HASH = hashlib.sha256(('github_actions' + 'sw_ip').encode()).hexdigest()[:16]


def post(title: str, content: str) -> str | None:
    """게시글 등록. 성공하면 새 글의 id를, 실패하면 None을 반환한다."""
    if not _SUPABASE_URL or not _SUPABASE_KEY:
        return None
    try:
        r = requests.post(
            f'{_SUPABASE_URL}/rest/v1/board_posts',
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
                'Content-Type':  'application/json',
                'Prefer':        'return=representation',
            },
            json={
                'title':         title,
                'nickname':      _NICK,
                'content':       content,
                'password_hash': _PW_HASH,
                'ip_hash':       _IP_HASH,
            },
            timeout=10,
        )
        if not r.ok:
            return None
        rows = r.json()
        return rows[0]['id'] if rows else None
    except Exception as e:
        print(f'⚠️  게시판 등록 실패: {e}')
        return None


def post_url(post_id: str) -> str:
    return f'https://stockwiki.vercel.app/?board={post_id}'


def screening_content(
    results: list, date_str: str,
    signals: list | None = None,
    excluded: list | None = None,
) -> str:
    """스크리닝 결과 HTML 생성 — 메일에 실제로 노출된 종목(통과·뉴스제외)만 기록한다.
    (점수 미달로 조용히 걸러진 나머지 스캔 대상까지 다 넣으면 메일 내용과 어긋난다)"""
    ok = sorted((r for r in results if r.get('pass')), key=lambda x: x['score'], reverse=True)

    signal_html = ''
    if signals:
        arrow_of = {1: '▲', -1: '▼', 0: '－'}
        bull = sum(1 for s in signals if s['direction'] > 0)
        bear = sum(1 for s in signals if s['direction'] < 0)
        neutral = len(signals) - bull - bear
        verdict = '강세 우세' if bull > bear else ('약세 우세' if bear > bull else '팽팽')
        chips = ' '.join(f"[{s['label']} {arrow_of[s['direction']]}]" for s in signals)
        signal_html = (
            f"<p><b>📍 당시 시장 신호:</b> 강세 {bull} · 약세 {bear} · 중립 {neutral} ({verdict})<br>"
            f"<span style='font-size:0.9em'>{chips}</span><br>"
            f"<span style='font-size:0.8em;opacity:0.7'>※ 통계적 확률이 아닌 단순 신호 조합입니다</span></p>"
        )

    excluded_html = ''
    if excluded:
        items = ''.join(
            f"<li>[{r['score']}/{r.get('max_score', 10)}점] {r['name']}({r['code']}) "
            f"— {r.get('sentiment_line', '')}</li>"
            for r in excluded
        )
        excluded_html = (
            f"<p><b>🔴 뉴스 부정으로 제외 ({len(excluded)}개):</b></p>"
            f"<ul>{items}</ul>"
        )

    rows = ''
    for r in ok:
        ratios = r.get('ratios') or {}
        ratio_parts = []
        if '부채비율'   in ratios: ratio_parts.append(f"부채{ratios['부채비율']:.0f}%")
        if '유동비율'   in ratios: ratio_parts.append(f"유동{ratios['유동비율']:.0f}%")
        if '현금비율'   in ratios: ratio_parts.append(f"현금{ratios['현금비율']:.0f}%")
        if '이자보상배율' in ratios: ratio_parts.append(f"이자보상{ratios['이자보상배율']:.0f}%")
        ratio_str = ' '.join(ratio_parts) or '-'
        disc = f"-{r['discount']:.1f}%" if r.get('discount') else '-'
        mcap = f"{r.get('market_cap', 0):,}억" if r.get('market_cap') else '-'
        rows += (
            f"<tr>"
            f"<td>✅ {r['name']}({r['code']})</td>"
            f"<td><b>{r['score']}/{r.get('max_score', 10)}점</b></td>"
            f"<td>{r['price']:,}원</td>"
            f"<td>MA60 {disc}</td>"
            f"<td>PER {r.get('per', 0):.1f} / PBR {r.get('pbr', 0):.2f}</td>"
            f"<td>{mcap}</td>"
            f"<td style='font-size:0.9em'>{ratio_str}</td>"
            f"</tr>"
        )
    th_style = "padding:6px;border-bottom:2px solid rgba(128,128,128,0.6);text-align:left"
    if not ok:
        rows = "<tr><td colspan='7' style='opacity:0.7'>진입 조건 통과 + 뉴스 감성 양호 종목 없음</td></tr>"
    return (
        f"{signal_html}"
        f"<p><b>스캔일:</b> {date_str} | <b>스캔대상:</b> {len(results)}종목 | <b>주목종목:</b> {len(ok)}종목</p>"
        f"<table cellpadding='6' cellspacing='0' style='border-collapse:collapse;width:100%'>"
        f"<thead><tr>"
        f"<th style='{th_style}'>종목</th><th style='{th_style}'>점수</th>"
        f"<th style='{th_style}'>현재가</th><th style='{th_style}'>MA60</th>"
        f"<th style='{th_style}'>PER/PBR</th><th style='{th_style}'>시총</th>"
        f"<th style='{th_style}'>재무비율</th>"
        f"</tr></thead>"
        f"<tbody>{rows}</tbody>"
        f"</table>"
        f"{excluded_html}"
    )


def buy_content(
    stock_name: str, stock_code: str,
    price: int, buy_amount: int, shares: int,
    score: float, max_score: int,
    log_lines: list,
    sell_opinion: str,
    ratios: dict,
) -> str:
    """매수 내역 HTML 생성"""
    ratio_parts = []
    if '부채비율'   in ratios: ratio_parts.append(f"부채비율 {ratios['부채비율']:.1f}%")
    if '유동비율'   in ratios: ratio_parts.append(f"유동비율 {ratios['유동비율']:.1f}%")
    if '현금비율'   in ratios: ratio_parts.append(f"현금비율 {ratios['현금비율']:.1f}%")
    if '이자보상배율' in ratios: ratio_parts.append(f"이자보상배율 {ratios['이자보상배율']:.1f}%")

    conditions = ''.join(f"<li>{line.strip()}</li>" for line in log_lines if line.strip())
    ratio_html = ' &nbsp;|&nbsp; '.join(ratio_parts) or '-'

    return (
        f"<p>"
        f"<b>종목:</b> {stock_name} ({stock_code})<br>"
        f"<b>매수가:</b> {price:,}원 &nbsp;|&nbsp; "
        f"<b>수량:</b> {shares}주 &nbsp;|&nbsp; "
        f"<b>금액:</b> {buy_amount:,}원<br>"
        f"<b>진입점수:</b> {score}/{max_score}점<br>"
        f"<b>재무비율:</b> {ratio_html}"
        f"</p>"
        f"<b>진입 조건:</b><ul>{conditions}</ul>"
        f"<b>AI 매도 의견:</b><p>{sell_opinion}</p>"
    )
