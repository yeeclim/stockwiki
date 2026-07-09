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


def post(title: str, content: str) -> bool:
    if not _SUPABASE_URL or not _SUPABASE_KEY:
        return False
    try:
        r = requests.post(
            f'{_SUPABASE_URL}/rest/v1/board_posts',
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
                'Content-Type':  'application/json',
                'Prefer':        'return=minimal',
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
        return r.ok
    except Exception as e:
        print(f'⚠️  게시판 등록 실패: {e}')
        return False


def screening_content(results: list, date_str: str) -> str:
    """스크리닝 결과 HTML 생성"""
    ok = [r for r in results if r.get('pass')]
    rows = ''
    for i, r in enumerate(results):
        ratios = r.get('ratios') or {}
        ratio_parts = []
        if '부채비율'   in ratios: ratio_parts.append(f"부채{ratios['부채비율']:.0f}%")
        if '유동비율'   in ratios: ratio_parts.append(f"유동{ratios['유동비율']:.0f}%")
        if '현금비율'   in ratios: ratio_parts.append(f"현금{ratios['현금비율']:.0f}%")
        if '이자보상배율' in ratios: ratio_parts.append(f"이자보상{ratios['이자보상배율']:.0f}%")
        ratio_str = ' '.join(ratio_parts) or '-'
        flag = '✅' if r.get('pass') else '▫️'
        disc = f"-{r['discount']:.1f}%" if r.get('discount') else '-'
        mcap = f"{r.get('market_cap', 0):,}억" if r.get('market_cap') else '-'
        rows += (
            f"<tr>"
            f"<td>{flag} {r['name']}({r['code']})</td>"
            f"<td><b>{r['score']}/{r.get('max_score', 11)}점</b></td>"
            f"<td>{r['price']:,}원</td>"
            f"<td>MA60 {disc}</td>"
            f"<td>PER {r.get('per', 0):.1f} / PBR {r.get('pbr', 0):.2f}</td>"
            f"<td>{mcap}</td>"
            f"<td style='font-size:0.9em'>{ratio_str}</td>"
            f"</tr>"
        )
    th_style = "padding:6px;border-bottom:2px solid rgba(128,128,128,0.6);text-align:left"
    return (
        f"<p><b>스캔일:</b> {date_str} | <b>대상:</b> {len(results)}종목 | <b>통과:</b> {len(ok)}종목</p>"
        f"<table cellpadding='6' cellspacing='0' style='border-collapse:collapse;width:100%'>"
        f"<thead><tr>"
        f"<th style='{th_style}'>종목</th><th style='{th_style}'>점수</th>"
        f"<th style='{th_style}'>현재가</th><th style='{th_style}'>MA60</th>"
        f"<th style='{th_style}'>PER/PBR</th><th style='{th_style}'>시총</th>"
        f"<th style='{th_style}'>재무비율</th>"
        f"</tr></thead>"
        f"<tbody>{rows}</tbody>"
        f"</table>"
    )


def buy_content(
    stock_name: str, stock_code: str,
    price: int, buy_amount: int, shares: int,
    score: int, max_score: int,
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
