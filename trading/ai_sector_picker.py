"""
AI 섹터별 종목 추천 — Claude API
스크리닝을 통과한 종목(screening_results pass=True) 목록을 Claude에게 전달하여
섹터 분류 및 추천 이유를 받아 screening_candidates(source='ai')에 저장.
Claude가 종목코드를 직접 생성하지 않으므로 hallucination 없음.

환경변수:
  ANTHROPIC_API_KEY        : Claude API 키
  SUPABASE_URL             : Supabase 프로젝트 URL
  SUPABASE_SERVICE_ROLE_KEY: Supabase 서비스 롤 키
"""
import os
import json
import requests
from datetime import datetime, timezone, timedelta
import pytz

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()
_SUPABASE_URL  = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY  = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()

SECTORS = ['반도체', 'AI', '데이터센터', '유리기판', '양자컴퓨터', '클라우드', '기타']
LOOKBACK_DAYS = 30   # 최근 N일 스크리닝 통과 종목을 풀로 사용


def _supabase_headers():
    return {
        'apikey':        _SUPABASE_KEY,
        'Authorization': f'Bearer {_SUPABASE_KEY}',
        'Content-Type':  'application/json',
    }


def _fetch_passed_stocks() -> list[dict]:
    """screening_results에서 최근 LOOKBACK_DAYS일 내 pass=True 종목 조회"""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)).isoformat()
    r = requests.get(
        f"{_SUPABASE_URL}/rest/v1/screening_results"
        f"?pass=eq.true&screened_at=gte.{cutoff}&order=score.desc,screened_at.desc",
        headers=_supabase_headers(),
        timeout=10,
    )
    r.raise_for_status()
    rows = r.json()

    # 동일 종목 중 최신 결과만 유지
    seen = set()
    result = []
    for row in rows:
        code = row['stock_code']
        if code not in seen:
            seen.add(code)
            result.append(row)
    return result


def _ask_claude(stocks: list[dict]) -> list[dict]:
    """스크리닝 통과 종목 목록을 주고 섹터 분류 + 추천 이유 요청"""
    stock_list = "\n".join([
        f"- {s['stock_name']}({s['stock_code']}): {s['score']}점/11점"
        f"  PER {s.get('per') or 'N/A'}  PBR {s.get('pbr') or 'N/A'}"
        f"  현재가 {s.get('price') or 'N/A'}원"
        for s in stocks
    ])

    prompt = f"""다음은 재무 스크리닝(PER·PBR·이동평균·부채비율·이자보상배율 등)을 통과한 한국 상장 종목들입니다.

{stock_list}

이 종목들을 아래 섹터 중 하나로 분류하고 추천 이유를 작성해주세요.
가능한 섹터: {', '.join(SECTORS)}
- 해당 섹터와 관련성이 낮은 종목은 '기타'로 분류
- 종목의 실제 사업 내용 기반으로 분류 (억측 금지)

반드시 아래 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
[
  {{"code": "000000", "name": "종목명", "sector": "섹터명", "reason": "추천 이유 1~2문장"}},
  ...
]

중요: 위 목록에 있는 종목코드와 종목명만 그대로 사용하세요. 새 종목 추가 금지."""

    resp = requests.post(
        'https://api.anthropic.com/v1/messages',
        headers={
            'x-api-key':         _ANTHROPIC_KEY,
            'anthropic-version': '2023-06-01',
            'content-type':      'application/json',
        },
        json={
            'model':      'claude-haiku-4-5-20251001',
            'max_tokens': 1024,
            'messages':   [{'role': 'user', 'content': prompt}],
        },
        timeout=30,
    )
    resp.raise_for_status()
    text = resp.json()['content'][0]['text'].strip()

    if '```' in text:
        text = text.split('```')[1].lstrip('json').strip()
    return json.loads(text)


def _clear_old_ai_candidates():
    """기존 source='ai' 종목 삭제 후 새로 채움"""
    r = requests.delete(
        f"{_SUPABASE_URL}/rest/v1/screening_candidates"
        "?source=eq.ai&user_id=is.null",
        headers=_supabase_headers(),
        timeout=10,
    )
    r.raise_for_status()


def _save_recommendations(recs: list[dict], passed_codes: set[str]):
    """Claude 추천 결과 저장 (스크리닝 통과 종목만, 코드 검증 후)"""
    # Claude가 목록 외 종목을 추가하는 hallucination 방지
    valid = [r for r in recs if r['code'] in passed_codes]
    invalid = [r for r in recs if r['code'] not in passed_codes]
    if invalid:
        print(f"  ⚠️  목록 외 종목 {len(invalid)}개 제거: {[r['name'] for r in invalid]}")

    if not valid:
        print("  저장할 유효 종목 없음")
        return 0

    rows = [
        {
            'stock_code': r['code'],
            'stock_name': r['name'],
            'sector':     r['sector'],
            'source':     'ai',
            'status':     'approved',
            'ai_reason':  r.get('reason', ''),
            'user_id':    None,
        }
        for r in valid
    ]
    resp = requests.post(
        f"{_SUPABASE_URL}/rest/v1/screening_candidates",
        headers={**_supabase_headers(), 'Prefer': 'resolution=ignore-duplicates,return=minimal'},
        json=rows,
        timeout=10,
    )
    resp.raise_for_status()
    print(f"  → {len(rows)}개 저장 완료")
    return len(rows)


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

    # 1. 스크리닝 통과 종목 조회
    stocks = _fetch_passed_stocks()
    if not stocks:
        print(f"⚠️  최근 {LOOKBACK_DAYS}일 내 스크리닝 통과 종목 없음 — 종료")
        return

    passed_codes = {s['stock_code'] for s in stocks}
    print(f"📋 스크리닝 통과 종목 {len(stocks)}개 로드")
    for s in stocks:
        print(f"  [{s['score']}점] {s['stock_name']}({s['stock_code']})")

    # 2. Claude에게 섹터 분류 + 추천 이유 요청
    print(f"\nClaude 섹터 분류 요청 중...")
    try:
        recs = _ask_claude(stocks)
        print(f"Claude 분류 완료: {len(recs)}개")
    except Exception as e:
        print(f"❌ Claude API 오류: {e}")
        return

    # 3. 기존 AI 추천 종목 교체
    print(f"\n기존 AI 추천 종목 초기화...")
    _clear_old_ai_candidates()

    # 4. 저장
    total = _save_recommendations(recs, passed_codes)
    print(f"\n✅ 완료 — {total}개 AI 추천 종목 저장")


if __name__ == '__main__':
    main()
