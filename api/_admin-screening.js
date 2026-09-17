// 관리자 스크리닝 종목 제외/복원 — api/utils.js 가 ?type=admin-candidate 로 라우팅한다.
// (Vercel Hobby 함수 12개 한도 때문에 별도 엔드포인트 파일을 만들지 않는다)
//
// 왜 서버에서 하나
// ----------------
// 예전엔 앱이 anon 키로 screening_candidates.is_active=false 를 직접 바꿨다. 그런데 RLS 는
// "본인이 추가한 행만 수정" 이라 시스템 종목은 0행 수정 + 에러 없음 → 앱은 "삭제됐습니다"
// 를 띄우지만 메일·추천에는 계속 나왔다. 게다가 매일 07:00 광역 스캔이 다시 활성화했다.
//
// 제외 표시
// ---------
// 해당 stock_code 의 모든 행을 status='rejected', is_active=false 로 바꾼다.
// screen_broad.py / screen.py / main.py 는 status='rejected' 인 종목코드를 통째로 건너뛴다.
// 이미 저장된 screening_results 도 pass=false 로 내려 추천 목록·자동매매 감시종목에서 즉시 빠지게 한다.
import { verifyAdmin } from './_shared.js';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');

async function db(path, { method = 'GET', body, prefer } = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1${path}`, {
    method,
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(10000),
  });
  const data = await res.json().catch(() => null);
  if (!res.ok) throw new Error(`DB ${res.status}: ${data?.message || ''}`);
  return data;
}

const CODE_RE = /^[0-9A-Z]{6}$/;

export async function handleAdminCandidate(req, res) {
  const adm = await verifyAdmin(req);
  if (!adm.ok) return res.status(adm.status).json({ success: false, error: adm.error });
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ success: false, error: 'DB 미설정' });
  }

  try {
    // 제외된 종목 목록 (복원 화면용) — 다른 사용자가 추가한 행은 RLS 상 앱에서 안 보이므로 서버가 준다
    if (req.method === 'GET') {
      const rows = await db(
        '/screening_candidates?status=eq.rejected&select=stock_code,stock_name,sector&order=stock_name'
      );
      const byCode = new Map();
      for (const r of rows) if (!byCode.has(r.stock_code)) byCode.set(r.stock_code, r);
      return res.status(200).json({ success: true, data: [...byCode.values()] });
    }

    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method not allowed' });
    }

    const { stockCode, action } = req.body ?? {};
    const code = typeof stockCode === 'string' ? stockCode.trim().toUpperCase() : '';
    if (!CODE_RE.test(code) || !['exclude', 'restore'].includes(action)) {
      return res.status(400).json({ success: false, error: 'stockCode(6자리)와 action(exclude|restore)이 필요합니다' });
    }

    if (action === 'exclude') {
      const updated = await db(`/screening_candidates?stock_code=eq.${code}`, {
        method: 'PATCH',
        prefer: 'return=representation',
        body: { status: 'rejected', is_active: false },
      });
      if (!updated?.length) {
        return res.status(404).json({ success: false, error: '해당 종목이 후보에 없습니다' });
      }
      // 이미 저장된 통과 결과도 내린다 → 추천 목록·자동매매 감시종목에서 즉시 제외
      await db(`/screening_results?stock_code=eq.${code}`, {
        method: 'PATCH',
        prefer: 'return=minimal',
        body: { pass: false },
      });
      return res.status(200).json({ success: true, updated: updated.length });
    }

    // restore: 제외 표시만 푼다. 통과 여부(screening_results)는 다음 스크리닝이 다시 판정한다.
    const restored = await db(`/screening_candidates?stock_code=eq.${code}&status=eq.rejected`, {
      method: 'PATCH',
      prefer: 'return=representation',
      body: { status: 'approved', is_active: true },
    });
    return res.status(200).json({ success: true, updated: restored?.length ?? 0 });
  } catch (e) {
    console.error('[admin-candidate]', e);
    return res.status(500).json({ success: false, error: '처리 중 오류가 발생했습니다' });
  }
}
