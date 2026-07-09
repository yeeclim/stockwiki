import { createHash } from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');
const MAX_PER_DAY  = 10;
const MAX_NICKNAME = 30;
const MAX_TITLE    = 100;
const MAX_CONTENT  = 10000;

function sha256(str, salt) {
  return createHash('sha256').update(str + salt).digest('hex');
}
function ipHash(ip) { return sha256(ip,  'sw_ip').substring(0, 16); }
function pwHash(pw) { return sha256(pw,  'sw_pw'); }

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
  if (!res.ok && method === 'GET') {
    console.error(`[board] DB ${res.status} ${path}`);
  }
  return res;
}

function sanitize(html) {
  if (!html) return '';
  let s = html
    .replace(/<(script|style|iframe|frame|object|embed|link|meta|base|form|input|button|select|textarea|svg)[\s\S]*?>/gi, '')
    .replace(/<\/(script|style|iframe|frame|object|embed|form|select|textarea|svg)>/gi, '')
    .replace(/\s+on\w+\s*=\s*["'][^"']*["']/gi, '')
    .replace(/\s+on\w+\s*=\s*[^\s>]+/gi, '')
    .replace(/href\s*=\s*["']\s*(javascript|vbscript|data):[^"']*/gi, 'href="#"')
    .replace(/src\s*=\s*["']\s*(javascript|vbscript):[^"']*/gi, 'src=""')
    .replace(/position\s*:\s*(fixed|absolute|sticky)/gi, 'position:relative')
    .replace(/<img([^>]*)>/gi, (_, attrs) => {
      const clean = attrs
        .replace(/style\s*=\s*["'][^"']*["']/gi, '')
        .replace(/width\s*=\s*["']?[^"'\s>]+["']?/gi, '')
        .replace(/height\s*=\s*["']?[^"'\s>]+["']?/gi, '');
      return `<img${clean} style="max-width:100%;max-height:400px;object-fit:contain;">`;
    })
    .replace(/<a([^>]*)>/gi, (_, attrs) => {
      const noTarget = attrs.replace(/target\s*=\s*["'][^"']*["']/gi, '');
      return `<a${noTarget} target="_blank" rel="noopener noreferrer">`;
    });
  return s.substring(0, MAX_CONTENT);
}

function stripHtml(html) {
  return (html || '')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ').trim();
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'DB 미설정' });
  }

  const rawIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim()
              || req.socket?.remoteAddress || 'unknown';
  const ih = ipHash(rawIp);

  try {
    // ── GET ──────────────────────────────────────────────────────────────────
    if (req.method === 'GET') {
      const { id, page = '1', limit = '20' } = req.query;

      if (id) {
        // 단건 조회 + 조회수 증가
        const r = await db(
          `/board_posts?id=eq.${id}&select=id,title,nickname,content,view_count,created_at,updated_at`
        );
        const data = await r.json();
        if (!data?.length) return res.status(404).json({ error: '게시글 없음' });

        await db(`/board_posts?id=eq.${id}`, {
          method: 'PATCH',
          prefer: 'return=minimal',
          body: { view_count: (data[0].view_count || 0) + 1 },
        });

        // 댓글 수
        const cr = await db(`/board_comments?post_id=eq.${id}&select=id`, { prefer: 'count=exact' });
        await cr.json();
        const commentCount = parseInt(cr.headers.get('content-range')?.split('/')[1] ?? '0') || 0;

        return res.json({ success: true, post: { ...data[0], comment_count: commentCount } });
      }

      // 목록
      const lim = Math.min(parseInt(limit) || 20, 50);
      const off = (Math.max(parseInt(page) || 1, 1) - 1) * lim;
      const r = await db(
        `/board_posts?select=id,title,nickname,content,view_count,created_at,updated_at&order=created_at.desc&limit=${lim}&offset=${off}`,
        { prefer: 'count=exact' }
      );
      const posts = await r.json();
      if (!r.ok || !Array.isArray(posts)) {
        const msg = posts?.message || posts?.error || `DB ${r.status}`;
        console.error('[board] list fetch failed:', msg, posts);
        return res.status(500).json({ error: '목록 조회 실패: ' + msg });
      }
      const total = parseInt(r.headers.get('content-range')?.split('/')[1] ?? '0') || 0;

      // 댓글 수 일괄 조회
      const ids = posts.map(p => p.id);
      let commentCounts = {};
      if (ids.length > 0) {
        const ccr = await db(
          `/board_comments?post_id=in.(${ids.join(',')})&select=post_id`
        );
        const ccData = await ccr.json();
        if (Array.isArray(ccData)) {
          for (const row of ccData) {
            commentCounts[row.post_id] = (commentCounts[row.post_id] || 0) + 1;
          }
        }
      }

      const list = (Array.isArray(posts) ? posts : []).map(p => ({
        id: p.id,
        title: p.title,
        nickname: p.nickname,
        preview: stripHtml(p.content).substring(0, 100),
        view_count: p.view_count || 0,
        comment_count: commentCounts[p.id] || 0,
        created_at: p.created_at,
        updated_at: p.updated_at,
      }));

      return res.json({ success: true, posts: list, total, page: parseInt(page), limit: lim });
    }

    // ── POST ─────────────────────────────────────────────────────────────────
    if (req.method === 'POST') {
      const { title, nickname, content, password } = req.body ?? {};

      if (!title?.trim() || !nickname?.trim() || !content?.trim() || !password?.trim())
        return res.status(400).json({ error: '제목·닉네임·내용·비밀번호를 모두 입력해주세요' });
      if (title.trim().length > MAX_TITLE)
        return res.status(400).json({ error: `제목은 ${MAX_TITLE}자 이하` });
      if (nickname.trim().length > MAX_NICKNAME)
        return res.status(400).json({ error: `닉네임은 ${MAX_NICKNAME}자 이하` });
      if (password.trim().length < 4)
        return res.status(400).json({ error: '비밀번호는 4자 이상' });

      const today = new Date().toISOString().split('T')[0];
      const cr = await db(`/board_posts?ip_hash=eq.${ih}&created_at=gte.${today}T00:00:00Z&select=id`);
      const todayPosts = await cr.json();
      if (Array.isArray(todayPosts) && todayPosts.length >= MAX_PER_DAY)
        return res.status(429).json({ error: `하루 최대 ${MAX_PER_DAY}개까지 작성 가능합니다` });

      const ir = await db('/board_posts', {
        method: 'POST',
        prefer: 'return=representation',
        body: {
          title:         title.trim().substring(0, MAX_TITLE),
          nickname:      nickname.trim().substring(0, MAX_NICKNAME),
          content:       sanitize(content),
          password_hash: pwHash(password.trim()),
          ip_hash:       ih,
        },
      });
      const inserted = await ir.json();
      if (!ir.ok) {
        const msg = inserted?.message || inserted?.error || `DB ${ir.status}`;
        console.error('[board] insert failed:', msg, inserted);
        return res.status(500).json({ error: '저장 실패: ' + msg });
      }
      return res.status(201).json({ success: true, id: inserted?.[0]?.id });
    }

    // ── PUT ──────────────────────────────────────────────────────────────────
    if (req.method === 'PUT') {
      const { id } = req.query;
      const { title, content, password } = req.body ?? {};
      if (!id || !content?.trim() || !password?.trim())
        return res.status(400).json({ error: '필수 값 누락' });

      const gr = await db(`/board_posts?id=eq.${id}&select=password_hash`);
      const rows = await gr.json();
      if (!rows?.length) return res.status(404).json({ error: '게시글 없음' });
      if (rows[0].password_hash !== pwHash(password.trim()))
        return res.status(403).json({ error: '비밀번호가 틀렸습니다' });

      const updateBody = {
        content:    sanitize(content),
        updated_at: new Date().toISOString(),
      };
      if (title?.trim()) updateBody.title = title.trim().substring(0, MAX_TITLE);

      await db(`/board_posts?id=eq.${id}`, {
        method: 'PATCH',
        prefer: 'return=minimal',
        body: updateBody,
      });
      return res.json({ success: true });
    }

    // ── DELETE ───────────────────────────────────────────────────────────────
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
