"""
뉴스 감성 분석 — Naver Finance 헤드라인 + Claude Haiku
스크리닝 통과 종목의 최신 뉴스를 분석하여 긍정/부정/중립 판별
"""
import os
import json
import requests
from bs4 import BeautifulSoup

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()
_EMOJI = {'긍정': '🟢', '부정': '🔴', '중립': '🟡'}


def get_headlines(stock_code: str, limit: int = 5) -> list[str]:
    """Naver Finance 종목 뉴스 헤드라인 스크래핑"""
    try:
        r = requests.get(
            f'https://finance.naver.com/item/news_news.naver?code={stock_code}&page=1',
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            timeout=8,
        )
        r.raise_for_status()
        soup = BeautifulSoup(r.content, 'lxml')
        titles = [
            a.get_text(strip=True)
            for a in soup.select('table.type5 td.title a')
            if a.get_text(strip=True)
        ]
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
    headlines = get_headlines(stock_code)
    if not headlines:
        return '뉴스 없음'
    result = _ask_claude(stock_name, headlines)
    if not result:
        return '분석 실패'
    sentiment = result.get('sentiment', '?')
    summary   = result.get('summary', '')
    emoji     = _EMOJI.get(sentiment, '⚪')
    return f"{emoji} {sentiment} — {summary}"
