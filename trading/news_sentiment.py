"""
뉴스 감성 분석 — Google 뉴스 RSS 헤드라인 + Claude Haiku
스크리닝 통과 종목의 최신 뉴스를 분석하여 긍정/부정/중립 판별
"""
import os
import json
from urllib.parse import quote
from xml.etree import ElementTree

import requests

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()
_EMOJI = {'긍정': '🟢', '부정': '🔴', '중립': '🟡'}


def get_headlines(stock_name: str, limit: int = 5) -> list[str]:
    """Google 뉴스 RSS에서 종목명 관련 헤드라인 조회"""
    try:
        encoded = quote(stock_name)
        url = f'https://news.google.com/rss/search?q={encoded}&hl=ko&gl=KR&ceid=KR:ko'
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
            # Google 뉴스 타이틀 형식: "기사 제목 - 언론사명"
            last_dash = full_title.rfind(' - ')
            title = full_title[:last_dash] if last_dash > 0 else full_title
            if title:
                titles.append(title)
        return titles[:limit]
    except Exception:
        return []


def _ask_claude(stock_name: str, headlines: list[str]) -> dict | None:
    if not _ANTHROPIC_KEY:
        return None
    prompt = (
        f"다음은 {stock_name} 관련 최신 뉴스 헤드라인입니다.\n\n"
        + '\n'.join(f'- {h}' for h in headlines)
        + "\n\n전반적인 감성을 분석하고 아래 JSON 형식으로만 응답하세요:\n"
        + '{"sentiment": "긍정" or "부정" or "중립", "summary": "한 줄 요약 (30자 이내)"}'
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
                'max_tokens': 120,
                'messages':   [{'role': 'user', 'content': prompt}],
            },
            timeout=15,
        )
        resp.raise_for_status()
        text = resp.json()['content'][0]['text'].strip()
        if '```' in text:
            text = text.split('```')[1].lstrip('json').strip()
        return json.loads(text)
    except Exception:
        return None


def get_sentiment_line(stock_code: str, stock_name: str) -> str:
    """감성 분석 결과를 한 줄 문자열로 반환"""
    headlines = get_headlines(stock_name)
    if not headlines:
        return '뉴스 없음'
    result = _ask_claude(stock_name, headlines)
    if not result:
        return '분석 실패'
    sentiment = result.get('sentiment', '?')
    summary   = result.get('summary', '')
    emoji     = _EMOJI.get(sentiment, '⚪')
    return f"{emoji} {sentiment} — {summary}"
