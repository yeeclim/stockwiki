"""
AI 섹터별 종목 추천 — Claude API
주간 GitHub Actions로 실행되어 각 섹터의 유망 종목을 추천하고
Supabase screening_candidates 테이블에 source='ai', status='ai_pending'으로 저장.
관리자가 앱에서 승인(approved) / 거절(rejected)을 결정함.

환경변수:
  ANTHROPIC_API_KEY        : Claude API 키
  SUPABASE_URL             : Supabase 프로젝트 URL
  SUPABASE_SERVICE_ROLE_KEY: Supabase 서비스 롤 키
"""
import os
import json
import requests
from datetime import datetime
import pytz

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()
_SUPABASE_URL  = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY  = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()

SECTORS = ['반도체', 'AI', '데이터센터', '유리기판', '양자컴퓨터', '클라우드']
STOCKS_PER_SECTOR = 8   # 섹터당 추천 종목 수


def _supabase_headers():
    return {
        'apikey':        _SUPABASE_KEY,
        'Authorization': f'Bearer {_SUPABASE_KEY}',
        'Content-Type':  'application/json',
        'Prefer':        'return=representation',
    }


def _ask_claude(sector: str) -> list[dict]:
    """Claude에게 섹터 관련 한국 상장 종목 추천 요청"""
    prompt = f"""당신은 한국 주식 전문가입니다.
현재 시장에서 **{sector}** 섹터와 관련된 한국 코스피/코스닥 상장 종목 {STOCKS_PER_SECTOR}개를 추천해주세요.

요구사항:
- 실제 상장된 종목만 (종목코드 6자리 숫자)
- {sector} 테마와 직접 관련된 사업을 영위하는 기업
- 시가총액, 실적, 시장 트렌드를 고려한 유망 종목
- 이미 잘 알려진 대형주와 성장 가능성 있는 중소형주 혼합

반드시 아래 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
[
  {{"code": "000000", "name": "종목명", "reason": "추천 이유 1~2문장"}},
  ...
]"""

    resp = requests.post(
        'https://api.anthropic.com/v1/messages',
        headers={
            'x-api-key':         _ANTHROPIC_KEY,
            'anthropic-version': '2023-06-01',
            'content-type':      'application/json',
        },
        json={
            'model':      'claude-opus-4-8',
            'max_tokens': 1024,
            'messages':   [{'role': 'user', 'content': prompt}],
        },
        timeout=30,
    )
    resp.raise_for_status()
    text = resp.json()['content'][0]['text'].strip()

    # JSON 파싱 (마크다운 코드블록 제거)
    if '```' in text:
        text = text.split('```')[1].lstrip('json').strip()
    return json.loads(text)


def _get_existing_codes() -> set[str]:
    """현재 approved/ai_pending 상태의 종목코드 조회 (중복 방지)"""
    r = requests.get(
        f"{_SUPABASE_URL}/rest/v1/screening_candidates"
        "?status=in.(approved,ai_pending)&select=stock_code",
        headers=_supabase_headers(),
        timeout=10,
    )
    r.raise_for_status()
    return {row['stock_code'] for row in r.json()}


def _save_recommendations(sector: str, stocks: list[dict], existing: set[str]):
    """AI 추천 종목을 Supabase에 저장 (신규만)"""
    new_stocks = [s for s in stocks if s['code'] not in existing]
    if not new_stocks:
        print(f"  → 신규 종목 없음 (모두 기존 보유)")
        return 0

    rows = [
        {
            'stock_code': s['code'],
            'stock_name': s['name'],
            'sector':     sector,
            'source':     'ai',
            'status':     'ai_pending',
            'ai_reason':  s.get('reason', ''),
            'user_id':    None,
        }
        for s in new_stocks
    ]
    r = requests.post(
        f"{_SUPABASE_URL}/rest/v1/screening_candidates",
        headers={**_supabase_headers(), 'Prefer': 'resolution=ignore-duplicates,return=minimal'},
        json=rows,
        timeout=10,
    )
    r.raise_for_status()
    print(f"  → {len(new_stocks)}개 저장 완료")
    return len(new_stocks)


def main():
    kst = pytz.timezone('Asia/Seoul')
    print(f"\n{'='*55}")
    print(f"  AI 섹터 종목 추천  |  {datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')}")
    print(f"{'='*55}\n")

    if not _ANTHROPIC_KEY:
        print("❌ ANTHROPIC_API_KEY 미설정")
        return
    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print("❌ Supabase 환경변수 미설정")
        return

    existing = _get_existing_codes()
    print(f"기존 종목 {len(existing)}개 확인 완료\n")

    total = 0
    for sector in SECTORS:
        print(f"[{sector}] Claude 추천 요청 중...")
        try:
            stocks = _ask_claude(sector)
            print(f"  Claude 추천: {[s['name'] for s in stocks]}")
            saved = _save_recommendations(sector, stocks, existing)
            total += saved
            # 기존 종목도 existing에 추가 (같은 실행 내 중복 방지)
            existing.update(s['code'] for s in stocks)
        except Exception as e:
            print(f"  ⚠️  [{sector}] 오류: {e}")

    print(f"\n✅ 완료 — 총 {total}개 신규 종목이 검토 대기(ai_pending) 상태로 저장됐습니다.")
    print("관리자 앱에서 승인/거절을 처리하세요.")


if __name__ == '__main__':
    main()
