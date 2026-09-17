// 스크리닝 메일 수신거부 — api/utils.js 가 ?type=unsubscribe 로 라우팅한다.
//
// 메일마다 사용자별 토큰이 든 링크가 들어간다 (trading/screen.py).
//   GET  : 확인 페이지만 보여준다. 메일 보안 스캐너가 링크를 미리 열어도 해지되지 않도록
//          실제 해지는 버튼(POST)으로만 한다.
//   POST : 해지. 메일 앱의 "구독 취소" 버튼(RFC 8058 List-Unsubscribe-Post)도 이 경로로 온다.
// 로그인이 필요 없어야 하므로 토큰 자체가 인증 수단이다 (추측 불가한 UUID, 클라이언트 조회 불가).

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function page(title, body) {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>${title} - StockWiki</title>
<style>
  body{font-family:-apple-system,'Noto Sans KR',sans-serif;max-width:480px;margin:60px auto;padding:0 16px;color:#222;line-height:1.6}
  button{background:#1565C0;color:#fff;border:0;border-radius:6px;padding:12px 20px;font-size:15px;cursor:pointer}
  a{color:#1565C0}
</style></head><body><h2>${title}</h2>${body}
<p style="margin-top:32px"><a href="https://stockwiki.vercel.app">StockWiki로 돌아가기</a></p></body></html>`;
}

export async function handleUnsubscribe(req, res) {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');

  const token = (req.query.token || '').toString();
  if (!UUID_RE.test(token)) {
    return res.status(400).send(page('잘못된 링크', '<p>수신거부 링크가 올바르지 않습니다. 앱의 마이페이지에서도 수신을 끌 수 있습니다.</p>'));
  }

  if (req.method === 'GET') {
    // 토큰은 UUID 형식 검증을 통과한 값만 들어가므로 HTML 에 그대로 넣어도 안전하다
    return res.status(200).send(page('스크리닝 메일 수신거부',
      `<p>StockWiki 스크리닝 메일을 더 이상 받지 않으시겠어요?</p>
       <form method="POST" action="/api/utils?type=unsubscribe&token=${token}">
         <button type="submit">수신거부</button>
       </form>`));
  }

  if (req.method !== 'POST') {
    return res.status(405).send(page('허용되지 않은 요청', ''));
  }
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).send(page('일시적인 오류', '<p>잠시 후 다시 시도해 주세요.</p>'));
  }

  try {
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/email_subscriptions?unsubscribe_token=eq.${token}`,
      {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        // night_opt_in 은 트리거가 함께 끈다. withdrawn_at 도 트리거가 기록한다.
        body: JSON.stringify({ email_opt_in: false }),
        signal: AbortSignal.timeout(10000),
      },
    );
    if (!r.ok) throw new Error(`DB ${r.status}`);
    const rows = await r.json();
    if (!rows.length) {
      return res.status(404).send(page('링크를 찾을 수 없음', '<p>이미 탈퇴했거나 만료된 링크입니다.</p>'));
    }
    return res.status(200).send(page('수신거부 완료',
      '<p>스크리닝 메일 수신이 해지되었습니다. 앱의 마이페이지에서 언제든 다시 받을 수 있습니다.</p>'));
  } catch (e) {
    console.error('[unsubscribe]', e);
    return res.status(500).send(page('일시적인 오류', '<p>잠시 후 다시 시도해 주세요.</p>'));
  }
}
