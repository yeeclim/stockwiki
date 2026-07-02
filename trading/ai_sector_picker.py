"""
AI 종목 추천 이유 생성 — Claude API
스크리닝을 통과한 종목(screening_results pass=True) 목록을 Claude에게 전달하여
추천 이유를 받아 screening_candidates 레코드의 ai_reason 컬럼을 업데이트.
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

LOOKBACK_DAYS = 30   # 최근 N일 스크리닝 통과 종목을 풀로 사용


def _supabase_headers():
    return {
        'apikey':        _SUPABASE_KEY,
        'Authorization': f'Bearer {_SUPABASE_KEY}',
        'Content-Type':  'application/json',
    }


def _fetch_passed_stocks() -> list[dict]:
    """screening_results에서 최근 LOOKBACK_DAYS일 내 pass=True 종목 조회"""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)).strftime('%Y-%m-%dT%H:%M:%SZ')
    r = requests.get(
        f"{_SUPABASE_URL}/rest/v1/screening_results"
        f"?pass=eq.true&score=gte.6&screened_at=gte.{cutoff}&order=score.desc,screened_at.desc",
        headers=_supabase_headers(),
        timeout=10,
    )
    r.raise_for_status()
    rows = r.json()

    # 동일 종목 중 최신 결과만 유지 + 시총 4천억 미만 제외
    seen = set()
    result = []
    for row in rows:
        code = row['stock_code']
        if code in seen:
            continue
        market_cap = row.get('market_cap', 0)
        if market_cap and market_cap < 4000:
            print(f"  ⛔ {row['stock_name']}({code}) 시총 {market_cap:,}억 — 제외")
            continue
        seen.add(code)
        result.append(row)
    return result


def _ask_claude(stocks: list[dict]) -> list[dict]:
    """스크리닝 통과 종목 목록을 주고 추천 이유 요청"""
    stock_list = "\n".join([
        f"- {s['stock_name']}({s['stock_code']}): {s['score']}점/11점"
        f"  PER {s.get('per') or 'N/A'}  PBR {s.get('pbr') or 'N/A'}"
        f"  현재가 {s.get('price') or 'N/A'}원"
        for s in stocks
    ])

    prompt = f"""다음은 재무 스크리닝(PER·PBR·이동평균·부채비율·이자보상배율 등)을 통과한 한국 상장 종목들입니다.

{stock_list}

각 종목에 대해 재무 지표와 사업 내용을 바탕으로 주목할 만한 이유를 1~2문장으로 작성해주세요.
- 실제 사업 내용 기반으로 작성 (억측 금지)
- 재무 지표(PER, PBR, 점수 등)를 구체적으로 언급

반드시 아래 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
[
  {{"code": "000000", "name": "종목명", "reason": "추천 이유 1~2문장"}},
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


def _update_reasons(recs: list[dict], passed_codes: set[str]):
    """Claude 추천 이유로 기존 system 레코드의 ai_reason 업데이트"""
    valid   = [r for r in recs if r['code'] in passed_codes]
    invalid = [r for r in recs if r['code'] not in passed_codes]
    if invalid:
        print(f"  ⚠️  목록 외 종목 {len(invalid)}개 제거: {[r['name'] for r in invalid]}")

    if not valid:
        print("  업데이트할 종목 없음")
        return 0

    updated = 0
    for r in valid:
        resp = requests.patch(
            f"{_SUPABASE_URL}/rest/v1/screening_candidates"
            f"?stock_code=eq.{r['code']}&user_id=is.null",
            headers=_supabase_headers(),
            json={'ai_reason': r.get('reason', '')},
            timeout=10,
        )
        if resp.ok:
            updated += 1
            print(f"  ✅ {r['name']}({r['code']}): {r.get('reason', '')[:40]}...")
        else:
            print(f"  ⚠️  업데이트 실패 {r['name']}({r['code']}): {resp.status_code}")
    return updated


def main():
    kst = pytz.timezone('Asia/Seoul')
    print(f"\n{'='*55}")
    print(f"  AI 종목 추천 이유 생성  |  {datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')}")
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

    # 2. Claude에게 추천 이유 요청
    print(f"\nClaude 추천 이유 생성 중...")
    try:
        recs = _ask_claude(stocks)
        print(f"Claude 완료: {len(recs)}개")
    except Exception as e:
        print(f"❌ Claude API 오류: {e}")
        return

    # 3. ai_reason 업데이트
    print(f"\nsupabase screening_candidates ai_reason 업데이트 중...")
    total = _update_reasons(recs, passed_codes)
    print(f"\n✅ 완료 — {total}개 종목 업데이트")


if __name__ == '__main__':
    main()
