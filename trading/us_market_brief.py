"""
간밤 미국시장 브리핑 — 주요 지수/섹터 ETF 등락률 + Claude 기반 이슈 요약
국내 스크리닝 메일(screen.py) 상단에 삽입되는 용도.
news_sentiment.py 와 동일한 패턴(Google News RSS + Claude Haiku)을 재사용한다.
"""
import os
import re
import html as html_lib
from datetime import datetime
from urllib.parse import quote
from xml.etree import ElementTree

import pytz
import requests

import us_market_data as umd
import kr_market_data as kmd

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()

_INDICES = [
    ('^GSPC', 'S&P 500'),
    ('^IXIC', '나스닥'),
    ('^DJI',  '다우'),
    ('^VIX',  'VIX'),
]

_SECTORS = [
    ('SMH', '반도체'),
    ('XLK', '기술'),
    ('XLE', '에너지'),
    ('XLF', '금융'),
    ('XLV', '헬스케어'),
    ('XLY', '임의소비재'),
]

_URL_RE = re.compile(r'https?://\S+')


# ── 데이터 수집 ────────────────────────────────────────────────────────────────

def _fetch_rows(items: list[tuple[str, str]]) -> list[dict]:
    symbols = [s for s, _ in items]
    quotes = umd.get_quotes_batch(symbols)
    rows = []
    for symbol, label in items:
        q = quotes.get(symbol)
        if not q:
            continue
        price = q.get('regularMarketPrice')
        pct = q.get('regularMarketChangePercent')
        if price is None or pct is None:
            continue
        rows.append({'symbol': symbol, 'label': label, 'price': price, 'pct': pct})
    return rows


def _get_market_headlines(limit: int = 6) -> list[str]:
    try:
        encoded = quote('Wall Street stock market')
        url = f'https://news.google.com/rss/search?q={encoded}&hl=en-US&gl=US&ceid=US:en'
        r = requests.get(
            url,
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            timeout=8,
        )
        r.raise_for_status()
        root = ElementTree.fromstring(r.content)
        titles = []
        for item in root.iter('item'):
            title_el = item.find('title')
            if title_el is None or not title_el.text:
                continue
            full_title = title_el.text.strip()
            last_dash = full_title.rfind(' - ')
            title = full_title[:last_dash] if last_dash > 0 else full_title
            if title:
                titles.append(title)
        return titles[:limit]
    except Exception:
        return []


def _summarize_issues(headlines: list[str], index_rows: list[dict], sector_rows: list[dict]) -> str:
    if not _ANTHROPIC_KEY or not headlines:
        return ''
    idx_str = ', '.join(f"{r['label']} {r['pct']:+.2f}%" for r in index_rows) or '데이터 없음'
    sec_str = ', '.join(f"{r['label']} {r['pct']:+.2f}%" for r in sector_rows) or '데이터 없음'
    prompt = (
        "다음은 간밤 미국 증시 관련 최신 뉴스 헤드라인과 실제 지수/섹터 등락률입니다.\n\n"
        f"지수 등락률: {idx_str}\n섹터 ETF 등락률: {sec_str}\n\n헤드라인:\n"
        + '\n'.join(f'- {h}' for h in headlines)
        + "\n\n이 정보를 바탕으로 한국 투자자를 위한 '간밤 미국시장 브리핑'을 한국어로 3~5줄로 작성하세요. "
          "지수/섹터 등락률 수치는 위에 주어진 값만 언급하고 새로운 수치를 지어내지 마세요. "
          "연준·실적발표·지정학 등 핵심 이슈를 중심으로 간결하게 서술하세요. "
          "설명 없이 브리핑 본문만 순수 텍스트로 응답하세요."
    )
    try:
        resp = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers={
                'x-api-key':         _ANTHROPIC_KEY,
                'anthropic-version': '2023-06-01',
                'content-type':      'application/json',
            },
            json={
                'model':      'claude-haiku-4-5-20251001',
                'max_tokens': 400,
                'messages':   [{'role': 'user', 'content': prompt}],
            },
            timeout=20,
        )
        resp.raise_for_status()
        return resp.json()['content'][0]['text'].strip()
    except Exception:
        return ''


def get_brief(kis_api=None) -> dict:
    """반환: {'indices', 'sectors', 'summary', 'kr_indices', 'kr_open_interest'}
    개별 단계가 실패해도 예외를 전파하지 않고 빈 값으로 안전하게 대체한다.
    kis_api(인증된 KISApi 인스턴스)를 넘기면 코스피200 선물 미결제약정도 함께 조회한다.
    """
    try:
        index_rows = _fetch_rows(_INDICES)
    except Exception as e:
        print(f"⚠️  미국 지수 조회 실패: {e}")
        index_rows = []
    try:
        sector_rows = _fetch_rows(_SECTORS)
    except Exception as e:
        print(f"⚠️  미국 섹터 ETF 조회 실패: {e}")
        sector_rows = []
    headlines = _get_market_headlines()
    summary = _summarize_issues(headlines, index_rows, sector_rows)

    try:
        kr_quotes = kmd.get_quotes()
    except Exception as e:
        print(f"⚠️  국내 지수 조회 실패: {e}")
        kr_quotes = {}
    kr_indices = [kr_quotes[c] for c in ('KOSPI', 'KOSDAQ', 'FUT') if c in kr_quotes]

    kr_open_interest = None
    if kis_api is not None:
        try:
            kr_open_interest = kis_api.get_futures_open_interest(kmd.kospi200_futures_code())
        except Exception as e:
            print(f"⚠️  선물 미결제약정 조회 실패: {e}")

    return {
        'indices': index_rows, 'sectors': sector_rows, 'summary': summary,
        'kr_indices': kr_indices, 'kr_open_interest': kr_open_interest,
    }


def render_text(brief: dict) -> str:
    """브리핑의 텍스트(plain) 버전. HTML을 못 받는 메일 클라이언트를 위한
    multipart/alternative 의 text/plain 파트에도 동일한 내용을 담기 위해 사용한다."""
    indices = brief.get('indices') or []
    sectors = brief.get('sectors') or []
    summary = (brief.get('summary') or '').strip()
    kr_indices = brief.get('kr_indices') or []
    kr_oi = brief.get('kr_open_interest')
    if not (indices or sectors or summary or kr_indices or kr_oi):
        return ''

    lines = ['🌙 간밤 미국시장 브리핑', '-' * 55]
    if indices:
        lines.append('[주요 지수] ' + '  '.join(
            f"{r['label']} {r['price']:,.2f} ({r['pct']:+.2f}%)" for r in indices))
    if sectors:
        lines.append('[섹터 ETF] ' + '  '.join(
            f"{r['label']} {r['pct']:+.2f}%" for r in sectors))
    if summary:
        lines.append('')
        lines.append(summary)
    if kr_indices or kr_oi:
        lines.append('')
        lines.append('[국내 마감 시황]')
        if kr_indices:
            lines.append('  ' + '  '.join(
                f"{r['label']} {r['price']:,.2f} ({r['pct']:+.2f}%)" for r in kr_indices))
        if kr_oi:
            chg = kr_oi['open_interest_change']
            arrow = '▲' if chg > 0 else ('▼' if chg < 0 else '－')
            lines.append(f"  코스피200 선물 미결제약정 {kr_oi['open_interest']:,}계약"
                          f" (전일대비 {arrow}{abs(chg):,})")
    lines.append('=' * 55)
    return '\n'.join(lines)


# ── HTML 렌더링 — StockWiki 앱과 동일한 블랙+네온 테마 (lib/theme/app_theme.dart 참고) ──

_BG           = '#050706'
_SURFACE      = '#0B0F0C'
_SURFACE_SOFT = '#0F1C15'
_LINE         = '#182620'
_INK          = '#EEF4EF'
_MUTED        = '#6C7A71'
_ACCENT       = '#39FF8C'   # 네온 그린
_UP           = '#FF4550'   # 상승 = 빨강 (국내 관행)
_DOWN         = '#3B82F6'   # 하락 = 파랑
_AMBER        = '#FFC94D'   # 중립/주의


def _chunk(seq: list, n: int) -> list[list]:
    return [seq[i:i + n] for i in range(0, len(seq), n)]


def _pct_color(pct: float) -> str:
    return _UP if pct >= 0 else _DOWN


def _chip_grid_html(title: str, rows: list[dict], cols: int) -> str:
    """지수/섹터 등락률을 네온 카드 그리드로 렌더링."""
    if not rows:
        return ''
    cell_w = f'{100 // cols}%'
    body = []
    for chunk in _chunk(rows, cols):
        cells = []
        for r in chunk:
            color = _pct_color(r['pct'])
            cells.append(
                f'<td width="{cell_w}" style="padding:5px;">'
                f'<div style="background:{_SURFACE_SOFT};border:1px solid {_LINE};'
                f'border-radius:10px;padding:10px 6px;text-align:center;">'
                f'<div style="color:{_MUTED};font-size:11px;letter-spacing:.2px;">{html_lib.escape(r["label"])}</div>'
                f'<div style="color:{_INK};font-size:14px;font-weight:700;margin-top:3px;font-family:Consolas,Menlo,monospace;">{r["price"]:,.2f}</div>'
                f'<div style="color:{color};font-size:12px;font-weight:700;margin-top:2px;font-family:Consolas,Menlo,monospace;">{r["pct"]:+.2f}%</div>'
                '</div></td>'
            )
        # 마지막 줄 셀 개수가 모자라면 빈 셀로 채워 정렬 유지
        while len(cells) < cols:
            cells.append(f'<td width="{cell_w}"></td>')
        body.append(f'<tr>{"".join(cells)}</tr>')
    return (
        f'<div style="color:{_MUTED};font-size:11px;font-weight:700;letter-spacing:.5px;'
        f'text-transform:uppercase;margin:14px 0 6px;">{html_lib.escape(title)}</div>'
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0">{"".join(body)}</table>'
    )


# ── 스크리닝 리포트 텍스트 하이라이팅 (터미널 스타일 <pre> 안에서 사용할 인라인 span만 삽입) ──

_SECTION_RE    = re.compile(r'^(✅|🔴|❌|⏸).*$', re.MULTILINE)
_SCORE_RE      = re.compile(r'\[(\d+(?:\.\d+)?)/(\d+)점\]')
_STOCK_RE      = re.compile(r'([^\s(]+)\(([\d*]{4,8})\)')
_CHANGE_RE     = re.compile(r'전일([+-]\d+\.\d+)%')
_SENTIMENT_RE  = re.compile(r'(📰 뉴스: )(🟢|🔴|🟡) (긍정|부정|중립)')


def _style_section_header(m: re.Match) -> str:
    line = m.group(0)
    color = {'✅': _ACCENT, '🔴': _UP, '❌': _MUTED, '⏸': _AMBER}.get(line[0], _INK)
    return f'<span style="color:{color};font-weight:700;">{line}</span>'


def _score_badge(m: re.Match) -> str:
    return (f'<span style="color:{_BG};background:{_ACCENT};font-weight:700;'
            f'padding:1px 6px;border-radius:4px;">{m.group(0)}</span>')


def _stock_name_code(m: re.Match) -> str:
    return (f'<b style="color:{_INK};">{m.group(1)}</b>'
            f'<span style="color:{_MUTED};">({m.group(2)})</span>')


def _change_pct(m: re.Match) -> str:
    val = m.group(1)
    color = _UP if val.startswith('+') else _DOWN
    return f'전일<span style="color:{color};font-weight:700;">{val}%</span>'


def _sentiment_word(m: re.Match) -> str:
    prefix, emoji, word = m.group(1), m.group(2), m.group(3)
    color = {'긍정': _ACCENT, '부정': _UP, '중립': _AMBER}.get(word, _INK)
    return f'{prefix}{emoji} <span style="color:{color};font-weight:700;">{word}</span>'


def _linkify(m: re.Match) -> str:
    url = m.group(0)
    return f'<a href="{url}" style="color:{_ACCENT};">{url}</a>'


def _highlight_report(report_text: str) -> str:
    """플레인 텍스트 리포트를 이스케이프 후, 알려진 패턴만 골라 인라인 색상을 입힌다."""
    text = html_lib.escape(report_text)
    text = _SECTION_RE.sub(_style_section_header, text)
    text = _SCORE_RE.sub(_score_badge, text)
    text = _STOCK_RE.sub(_stock_name_code, text)
    text = _CHANGE_RE.sub(_change_pct, text)
    text = _SENTIMENT_RE.sub(_sentiment_word, text)
    text = _URL_RE.sub(_linkify, text)
    return text


_STYLE_BLOCK = f"""
<style>
  @keyframes swkPulse {{ 0%, 100% {{ opacity: 1; }} 50% {{ opacity: .35; }} }}
  @keyframes swkGlow {{
    0%, 100% {{ text-shadow: 0 0 8px rgba(57,255,140,.55), 0 0 18px rgba(57,255,140,.25); }}
    50%      {{ text-shadow: 0 0 14px rgba(57,255,140,.85), 0 0 28px rgba(57,255,140,.4); }}
  }}
  .swk-dot  {{ animation: swkPulse 1.6s ease-in-out infinite; }}
  .swk-logo {{ animation: swkGlow 3s ease-in-out infinite; }}
  a {{ text-decoration: none; }}
  @media (max-width: 480px) {{
    .swk-container {{ width: 100% !important; }}
  }}
</style>
"""


def render_email_html(brief: dict, report_text: str) -> str:
    """브리핑 + 기존 텍스트 리포트를 StockWiki 블랙+네온 테마의 완성된 HTML 문서로 반환한다."""
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y.%m.%d (%a) %H:%M KST')

    indices_html = _chip_grid_html('주요 지수', brief.get('indices') or [], cols=2)
    sectors_html = _chip_grid_html('섹터 ETF', brief.get('sectors') or [], cols=3)
    summary = (brief.get('summary') or '').strip()
    summary_html = ''
    if summary:
        summary_html = (
            f'<div style="margin-top:14px;padding:12px 14px;background:{_SURFACE_SOFT};'
            f'border-left:3px solid {_ACCENT};border-radius:6px;color:{_INK};'
            f'font-size:13px;line-height:1.75;white-space:pre-wrap;">{html_lib.escape(summary)}</div>'
        )

    brief_section = ''
    if indices_html or sectors_html or summary_html:
        brief_section = f"""
<tr><td style="padding-bottom:16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="padding:18px 20px;">
      <span class="swk-dot" style="display:inline-block;width:8px;height:8px;border-radius:50%;
            background:{_ACCENT};box-shadow:0 0 6px {_ACCENT};vertical-align:middle;"></span>
      <span style="color:{_INK};font-weight:700;font-size:14px;vertical-align:middle;margin-left:8px;">
        간밤 미국시장 브리핑
      </span>
      {indices_html}
      {sectors_html}
      {summary_html}
    </td></tr>
  </table>
</td></tr>"""

    kr_indices_html = _chip_grid_html('지수 · 선물', brief.get('kr_indices') or [], cols=3)
    kr_oi = brief.get('kr_open_interest')
    kr_oi_html = ''
    if kr_oi:
        chg = kr_oi['open_interest_change']
        oi_color = _UP if chg > 0 else (_DOWN if chg < 0 else _MUTED)
        arrow = '▲' if chg > 0 else ('▼' if chg < 0 else '－')
        kr_oi_html = (
            f'<div style="margin-top:10px;color:{_MUTED};font-size:12px;">'
            f'코스피200 선물 미결제약정 '
            f'<span style="color:{_INK};font-weight:700;font-family:Consolas,Menlo,monospace;">{kr_oi["open_interest"]:,}</span>계약'
            f'&nbsp; <span style="color:{oi_color};font-weight:700;font-family:Consolas,Menlo,monospace;">{arrow}{abs(chg):,}</span>'
            f'</div>'
        )

    kr_section = ''
    if kr_indices_html or kr_oi_html:
        kr_section = f"""
<tr><td style="padding-bottom:16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="padding:18px 20px;">
      <span class="swk-dot" style="display:inline-block;width:8px;height:8px;border-radius:50%;
            background:{_ACCENT};box-shadow:0 0 6px {_ACCENT};vertical-align:middle;"></span>
      <span style="color:{_INK};font-weight:700;font-size:14px;vertical-align:middle;margin-left:8px;">
        국내 마감 시황
      </span>
      {kr_indices_html}
      {kr_oi_html}
    </td></tr>
  </table>
</td></tr>"""

    report_html = f"""
<tr><td>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="background:{_SURFACE_SOFT};border-bottom:1px solid {_LINE};
                   border-radius:12px 12px 0 0;padding:10px 16px;">
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#FF5F56;margin-right:5px;"></span>
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#FFBD2E;margin-right:5px;"></span>
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#27C93F;margin-right:8px;"></span>
      <span style="color:{_MUTED};font-size:11px;font-family:Consolas,Menlo,monospace;">screening_result.log</span>
    </td></tr>
    <tr><td style="padding:16px;">
      <pre style="margin:0;white-space:pre-wrap;word-break:break-word;
                  font-family:Consolas,Menlo,monospace;font-size:12.5px;line-height:1.6;
                  color:{_INK};">{_highlight_report(report_text)}</pre>
    </td></tr>
  </table>
</td></tr>"""

    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="supported-color-schemes" content="dark">
<title>StockWiki</title>
{_STYLE_BLOCK}
</head>
<body style="margin:0;padding:0;background-color:{_BG};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">
  오늘의 종목 스크리닝 결과, 국내 마감 시황, 간밤 미국시장 브리핑
</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:{_BG};">
<tr><td align="center" style="padding:28px 12px;">
<table role="presentation" width="640" class="swk-container" cellpadding="0" cellspacing="0" style="width:640px;max-width:100%;">
  <tr><td style="text-align:center;padding-bottom:22px;">
    <span class="swk-logo" style="font-family:Consolas,Menlo,monospace;font-size:22px;
          font-weight:800;color:{_ACCENT};letter-spacing:3px;">STOCKWIKI</span>
    <div style="color:{_MUTED};font-size:12px;margin-top:6px;font-family:Consolas,Menlo,monospace;">
      {now_str} · 종목 스크리닝
    </div>
  </td></tr>
  {kr_section}
  {brief_section}
  {report_html}
  <tr><td style="text-align:center;padding-top:22px;color:{_MUTED};font-size:11px;">
    이 메일은 StockWiki 자동 스크리닝 시스템이 발송했습니다.
  </td></tr>
</table>
</td></tr>
</table>
</body>
</html>"""
