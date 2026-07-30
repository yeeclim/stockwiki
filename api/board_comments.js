import { createHash } from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');
const MAX_PER_DAY  = 30;
const MAX_NICKNAME = 30;
const MAX_CONTENT  = 1000;

function sha256(str, salt) {
  return createHash('sha256').update(str + salt).digest('hex');
}
function ipHash(ip) { return sha256(ip,  'sw_ip').substring(0, 16); }
function pwHash(pw) { return sha256(pw,  'sw_pw'); }

// board_posts.id / board_comments.id는 bigserial이므로 양의 정수만 허용한다.
// 검증 없이 쿼리 문자열에 그대로 넣으면 &로 추가 PostgREST 파라미터를 주입할 수 있다.
function toPositiveIntId(value) {
  if (Array.isArray(value)) return null;
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}

async function db(path, options = {}) {
  const { method = 'GET', body, prefer } = options;
  const headers = {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json',
    ...(prefer ? { Prefer: prefer } : {}),
  };
  const res = await fetch(`${SUPABASE_URL}/rest/v1${path}`, {
    method, headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    console.error(`[board_comments] DB ${res.status} ${path}`);
  }
  return res;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'DB 미설정' });
  }

  const rawIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim()
              || req.socket?.remoteAddress || 'unknown';
  const ih = ipHash(rawIp);

  try {
    // ── GET: 댓글 목록 ───────────────────────────────────────────────────────
    if (req.method === 'GET') {
      const post_id = toPositiveIntId(req.query.post_id);
      if (post_id === null) return res.status(400).json({ error: 'post_id 필요' });

      const r = await db(
        `/board_comments?post_id=eq.${post_id}&select=id,nickname,content,created_at&order=created_at.asc`
      );
      const data = await r.json();
      return res.json({ success: true, comments: Array.isArray(data) ? data : [] });
    }

    // ── POST: 댓글 작성 ──────────────────────────────────────────────────────
    if (req.method === 'POST') {
      const { nickname, content, password } = req.body ?? {};
      const post_id = toPositiveIntId(req.body?.post_id);

      if (post_id === null || !nickname?.trim() || !content?.trim() || !password?.trim())
        return res.status(400).json({ error: '닉네임·내용·비밀번호를 모두 입력해주세요' });
      if (nickname.trim().length > MAX_NICKNAME)
        return res.status(400).json({ error: `닉네임은 ${MAX_NICKNAME}자 이하` });
      if (content.trim().length > MAX_CONTENT)
        return res.status(400).json({ error: `댓글은 ${MAX_CONTENT}자 이하` });
      if (password.trim().length < 4)
        return res.status(400).json({ error: '비밀번호는 4자 이상' });

      // 게시글 존재 확인
      const pr = await db(`/board_posts?id=eq.${post_id}&select=id`);
      const postData = await pr.json();
      if (!postData?.length) return res.status(404).json({ error: '게시글 없음' });

      // 일일 댓글 수 제한
      const today = new Date().toISOString().split('T')[0];
      const cr = await db(`/board_comments?ip_hash=eq.${ih}&created_at=gte.${today}T00:00:00Z&select=id`);
      const todayComments = await cr.json();
      if (Array.isArray(todayComments) && todayComments.length >= MAX_PER_DAY)
        return res.status(429).json({ error: `하루 최대 ${MAX_PER_DAY}개까지 작성 가능합니다` });

      const ir = await db('/board_comments', {
        method: 'POST',
        prefer: 'return=representation',
        body: {
          post_id:       parseInt(post_id),
          nickname:      nickname.trim().substring(0, MAX_NICKNAME),
          content:       content.trim().substring(0, MAX_CONTENT),
          password_hash: pwHash(password.trim()),
          ip_hash:       ih,
        },
      });
      const inserted = await ir.json();
      return res.status(201).json({ success: true, id: inserted?.[0]?.id });
    }

    // ── DELETE: 댓글 삭제 ────────────────────────────────────────────────────
    if (req.method === 'DELETE') {
      const { password } = req.body ?? {};
      const id = toPositiveIntId(req.query.id);
      if (id === null || !password?.trim())
        return res.status(400).json({ error: '필수 값 누락' });

      const gr = await db(`/board_comments?id=eq.${id}&select=password_hash`);
      const rows = await gr.json();
      if (!rows?.length) return res.status(404).json({ error: '댓글 없음' });
      if (rows[0].password_hash !== pwHash(password.trim()))
        return res.status(403).json({ error: '비밀번호가 틀렸습니다' });

      await db(`/board_comments?id=eq.${id}`, { method: 'DELETE' });
      return res.json({ success: true });
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (e) {
    console.error('board_comments error:', e);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
}
