import { createHash } from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');
const MAX_PER_DAY   = 10;
const MAX_NICKNAME  = 30;
const MAX_CONTENT   = 10000;

// ── 헬퍼 ──────────────────────────────────────────────────────────────────────
function sha256(str, salt) {
  return createHash('sha256').update(str + salt).digest('hex');
}
function ipHash(ip)  { return sha256(ip,  'sw_ip').substring(0, 16); }
function pwHash(pw)  { return sha256(pw,  'sw_pw'); }

async function db(path, options = {}) {
  const { method = 'GET', body, prefer } = options;
  const headers = {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json',
    ...(prefer ? { Prefer: prefer } : {}),
  };
  const url = `${SUPABASE_URL}/rest/v1${path}`;
  const res = await fetch(url, {
    method, headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok && method === 'GET') {
    const text = await res.text();
    console.error(`[board] DB error ${res.status} ${url}: ${text}`);
  }
  return res;
}

// ── HTML 새니타이저 (화이트리스트 방식) ───────────────────────────────────────
function sanitize(html) {
  if (!html) return '';
  let s = html
    // 위험한 태그 통째로 제거
    .replace(/<(script|style|iframe|frame|object|embed|link|meta|base|form|input|button|select|textarea|svg)[\s\S]*?>/gi, '')
    .replace(/<\/(script|style|iframe|frame|object|embed|form|select|textarea|svg)>/gi, '')
    // 이벤트 핸들러 제거
    .replace(/\s+on\w+\s*=\s*["'][^"']*["']/gi, '')
    .replace(/\s+on\w+\s*=\s*[^\s>]+/gi, '')
    // 위험한 프로토콜 제거
    .replace(/href\s*=\s*["']\s*(javascript|vbscript|data):[^"']*/gi, 'href="#"')
    .replace(/src\s*=\s*["']\s*(javascript|vbscript):[^"']*/gi, 'src=""')
    // position:fixed/absolute → relative (레이아웃 탈출 방지)
    .replace(/position\s*:\s*(fixed|absolute|sticky)/gi, 'position:relative')
    // 이미지 크기 제한
    .replace(/<img([^>]*)>/gi, (_, attrs) => {
      const clean = attrs.replace(/style\s*=\s*["'][^"']*["']/gi, '').replace(/width\s*=\s*["']?[^"'\s>]+["']?/gi, '').replace(/height\s*=\s*["']?[^"'\s>]+["']?/gi, '');
      return `<img${clean} style="max-width:100%;max-height:400px;object-fit:contain;">`;
    })
    // 외부 링크 안전 처리
    .replace(/<a([^>]*)>/gi, (_, attrs) => {
      const noTarget = attrs.replace(/target\s*=\s*["'][^"']*["']/gi, '');
      return `<a${noTarget} target="_blank" rel="noopener noreferrer">`;
    });
  return s.substring(0, MAX_CONTENT);
}

function stripHtml(html) {
  return (html || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
}

// ── 메인 핸들러 ────────────────────────────────────────────────────────────────
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'DB 미설정 (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)' });
  }

  const rawIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim()
              || req.socket?.remoteAddress || 'unknown';
  const ih = ipHash(rawIp);

  try {
    // ── GET: 목록 / 단건 조회 ──────────────────────────────────────────────
    if (req.method === 'GET') {
      const { id, page = '1', limit = '20' } = req.query;

      if (id) {
        const r = await db(`/board_posts?id=eq.${id}&select=id,nickname,content,created_at,updated_at`);
        const data = await r.json();
        if (!data?.length) return res.status(404).json({ error: '게시글 없음' });
        return res.json({ success: true, post: data[0] });
      }

      const lim = Math.min(parseInt(limit) || 20, 50);
      const off = (Math.max(parseInt(page) || 1, 1) - 1) * lim;
      const r = await db(
        `/board_posts?select=id,nickname,content,created_at,updated_at&order=created_at.desc&limit=${lim}&offset=${off}`,
        { prefer: 'count=exact' }
      );
      const posts = await r.json();
      const total = parseInt(r.headers.get('content-range')?.split('/')[1] ?? '0') || 0;
      // 목록에서는 HTML 제거한 preview 추가
      const list = (Array.isArray(posts) ? posts : []).map(p => ({
        ...p,
        preview: stripHtml(p.content).substring(0, 120),
        content: undefined, // 목록에선 전체 내용 미포함
      }));
      return res.json({ success: true, posts: list, total, page: parseInt(page), limit: lim });
    }

    // ── POST: 작성 ─────────────────────────────────────────────────────────
    if (req.method === 'POST') {
      const { nickname, content, password } = req.body ?? {};

      if (!nickname?.trim() || !content?.trim() || !password?.trim())
        return res.status(400).json({ error: '닉네임·내용·비밀번호를 모두 입력해주세요' });
      if (nickname.trim().length > MAX_NICKNAME)
        return res.status(400).json({ error: `닉네임은 ${MAX_NICKNAME}자 이하` });
      if (password.trim().length < 4)
        return res.status(400).json({ error: '비밀번호는 4자 이상' });

      // 오늘 작성 수 체크
      const today = new Date().toISOString().split('T')[0];
      const cr = await db(`/board_posts?ip_hash=eq.${ih}&created_at=gte.${today}T00:00:00Z&select=id`);
      const todayPosts = await cr.json();
      if (Array.isArray(todayPosts) && todayPosts.length >= MAX_PER_DAY)
        return res.status(429).json({ error: `하루 최대 ${MAX_PER_DAY}개까지 작성 가능합니다` });

      const ir = await db('/board_posts', {
        method: 'POST',
        prefer: 'return=representation',
        body: {
          nickname: nickname.trim().substring(0, MAX_NICKNAME),
          content:  sanitize(content),
          password_hash: pwHash(password.trim()),
          ip_hash: ih,
        },
      });
      const inserted = await ir.json();
      return res.status(201).json({ success: true, id: inserted?.[0]?.id });
    }

    // ── PUT: 수정 ──────────────────────────────────────────────────────────
    if (req.method === 'PUT') {
      const { id } = req.query;
      const { content, password } = req.body ?? {};
      if (!id || !content?.trim() || !password?.trim())
        return res.status(400).json({ error: '필수 값 누락' });

      const gr = await db(`/board_posts?id=eq.${id}&select=password_hash`);
      const rows = await gr.json();
      if (!rows?.length) return res.status(404).json({ error: '게시글 없음' });
      if (rows[0].password_hash !== pwHash(password.trim()))
        return res.status(403).json({ error: '비밀번호가 틀렸습니다' });

      await db(`/board_posts?id=eq.${id}`, {
        method: 'PATCH',
        prefer: 'return=minimal',
        body: { content: sanitize(content), updated_at: new Date().toISOString() },
      });
      return res.json({ success: true });
    }

    // ── DELETE: 삭제 ───────────────────────────────────────────────────────
    if (req.method === 'DELETE') {
      const { id } = req.query;
      const { password } = req.body ?? {};
      if (!id || !password?.trim())
        return res.status(400).json({ error: '필수 값 누락' });

      const gr = await db(`/board_posts?id=eq.${id}&select=password_hash`);
      const rows = await gr.json();
      if (!rows?.length) return res.status(404).json({ error: '게시글 없음' });
      if (rows[0].password_hash !== pwHash(password.trim()))
        return res.status(403).json({ error: '비밀번호가 틀렸습니다' });

      await db(`/board_posts?id=eq.${id}`, { method: 'DELETE' });
      return res.json({ success: true });
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (e) {
    console.error('board error:', e.message);
    return res.status(500).json({ error: '서버 오류: ' + e.message });
  }
}
