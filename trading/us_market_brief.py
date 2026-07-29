"""
간밤 미국시장 브리핑 — 주요 지수/섹터 ETF 등락률 + Claude 기반 이슈 요약
국내 스크리닝 메일(screen.py) 상단에 삽입되는 용도.
news_sentiment.py 와 동일한 패턴(Google News RSS + Claude Haiku)을 재사용한다.
"""
import os
import re
import html as html_lib
from urllib.parse import quote
from xml.etree import ElementTree

import requests

import us_market_data as umd

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


def get_brief() -> dict:
    """반환: {'indices': [...], 'sectors': [...], 'summary': str}
    개별 단계가 실패해도 예외를 전파하지 않고 빈 값으로 안전하게 대체한다.
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
    return {'indices': index_rows, 'sectors': sector_rows, 'summary': summary}


def render_text(brief: dict) -> str:
    """브리핑의 텍스트(plain) 버전. HTML을 못 받는 메일 클라이언트를 위한
    multipart/alternative 의 text/plain 파트에도 동일한 내용을 담기 위해 사용한다."""
    indices = brief.get('indices') or []
    sectors = brief.get('sectors') or []
    summary = (brief.get('summary') or '').strip()
    if not (indices or sectors or summary):
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
    lines.append('=' * 55)
    return '\n'.join(lines)


# ── HTML 렌더링 ────────────────────────────────────────────────────────────────

_UP_COLOR = '#d6392a'    # 상승 = 빨강 (국내 관행)
_DOWN_COLOR = '#2a5cd6'  # 하락 = 파랑


def _pct_span(pct: float) -> str:
    color = _UP_COLOR if pct >= 0 else _DOWN_COLOR
    return f'<span style="color:{color};font-weight:600;">{pct:+.2f}%</span>'


def _rows_table_html(title: str, rows: list[dict]) -> str:
    if not rows:
        return ''
    cells = []
    for r in rows:
        cells.append(
            '<td style="padding:8px 12px;border:1px solid #e2e2e2;text-align:center;">'
            f'<div style="font-size:12px;color:#666;">{html_lib.escape(r["label"])}</div>'
            f'<div style="font-size:14px;">{r["price"]:,.2f}</div>'
            f'<div style="font-size:13px;">{_pct_span(r["pct"])}</div>'
            '</td>'
        )
    return (
        f'<div style="margin:12px 0 4px;font-weight:600;font-size:14px;">{html_lib.escape(title)}</div>'
        '<table style="border-collapse:collapse;width:100%;">'
        f'<tr>{"".join(cells)}</tr>'
        '</table>'
    )


def _report_to_html_pre(report_text: str) -> str:
    """기존 텍스트 리포트를 이스케이프 후 URL만 링크로 바꿔 <pre>로 감싼다."""
    escaped = html_lib.escape(report_text)

    def _linkify(m: re.Match) -> str:
        url = m.group(0)
        return f'<a href="{url}">{url}</a>'

    linked = _URL_RE.sub(_linkify, escaped)
    return (
        '<pre style="white-space:pre-wrap;word-break:break-word;'
        'font-family:Consolas,Menlo,monospace;font-size:13px;'
        'background:#f7f7f7;border-radius:8px;padding:16px;">'
        f'{linked}</pre>'
    )


def render_email_html(brief: dict, report_text: str) -> str:
    """브리핑 + 기존 텍스트 리포트를 합친 완성된 HTML 문서를 반환한다."""
    summary_html = ''
    if brief.get('summary'):
        summary_html = (
            '<div style="margin:12px 0;padding:12px 16px;background:#eef2ff;'
            'border-radius:8px;line-height:1.6;font-size:14px;white-space:pre-wrap;">'
            f'{html_lib.escape(brief["summary"])}</div>'
        )

    indices_html = _rows_table_html('주요 지수', brief.get('indices') or [])
    sectors_html = _rows_table_html('섹터 ETF', brief.get('sectors') or [])

    brief_section = ''
    if summary_html or indices_html or sectors_html:
        brief_section = (
            '<div style="margin-bottom:20px;">'
            '<h2 style="font-size:16px;margin:0 0 8px;">🌙 간밤 미국시장 브리핑</h2>'
            f'{indices_html}{sectors_html}{summary_html}'
            '</div>'
            '<hr style="border:none;border-top:1px solid #e2e2e2;margin:16px 0;">'
        )

    return (
        '<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;'
        'color:#222;max-width:640px;margin:0 auto;">'
        f'{brief_section}'
        f'{_report_to_html_pre(report_text)}'
        '</div>'
    )
