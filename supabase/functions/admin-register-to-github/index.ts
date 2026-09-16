/**
 * Supabase Edge Function: admin-register-to-github
 *
 * Allows a trusted operator (with ADMIN_API_KEY) to upsert `trading_configs`
 * for any `user_id`. This is intended for administrative workflows only.
 *
 * ⚠️ 이름과 달리 GitHub 에는 아무것도 등록하지 않습니다. 읽는 곳이 없는
 *    USR_<uid>_* repo secrets 사본을 제거했습니다 — register-to-github 쪽
 *    헤더 주석에 경위가 적혀 있습니다.
 *
 * KIS 자격증명은 AES-256-GCM 으로 암호화해 저장합니다 (../_shared/crypto.ts).
 * Supabase Secrets: TRADING_ENC_KEY (base64 32바이트, GitHub Secrets 와 동일 값)
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";
import { encryptField } from "../_shared/crypto.ts";

const ADMIN_API_KEY = Deno.env.get("ADMIN_API_KEY") ?? "";

// 실계좌 API 키를 다루는 엔드포인트이므로 단순 문자열 비교 대신 타이밍 공격에
// 안전한 비교와, 같은 인스턴스 내에서의 무차별 대입 시도를 늦추는 rate limit을 둔다.
async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);
  const bytesA = new Uint8Array(digestA);
  const bytesB = new Uint8Array(digestB);
  let diff = 0;
  for (let i = 0; i < bytesA.length; i++) {
    diff |= bytesA[i] ^ bytesB[i];
  }
  return diff === 0;
}

const AUTH_ATTEMPTS = new Map<string, { count: number; resetAt: number }>();
const AUTH_WINDOW_MS = 60_000;
const AUTH_MAX_ATTEMPTS = 5;

function isRateLimited(clientKey: string): boolean {
  const now = Date.now();
  const entry = AUTH_ATTEMPTS.get(clientKey);
  if (!entry || now > entry.resetAt) {
    AUTH_ATTEMPTS.set(clientKey, { count: 1, resetAt: now + AUTH_WINDOW_MS });
    return false;
  }
  entry.count++;
  return entry.count > AUTH_MAX_ATTEMPTS;
}

interface RequestBody {
  user_id: string;
  broker_type?: string;
  kis_app_key: string;
  kis_app_secret: string;
  kis_account_no: string;
  kis_account_prod_code?: string;
  notify_kakao_refresh_token?: string;
  notify_email?: string;
  daily_max_buy?: number | string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, X-Admin-Secret",
      },
    });
  }

  const clientKey = req.headers.get('x-forwarded-for') ?? 'unknown';
  if (isRateLimited(clientKey)) {
    return json({ error: 'too many attempts, try again later' }, 429);
  }

  const adminHeader = req.headers.get('x-admin-secret') ?? '';
  if (!ADMIN_API_KEY || !(await timingSafeEqual(adminHeader, ADMIN_API_KEY))) {
    return json({ error: 'unauthorized' }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid request body' }, 400);
  }

  const { user_id, broker_type, kis_app_key, kis_app_secret, kis_account_no, kis_account_prod_code, notify_kakao_refresh_token, notify_email, daily_max_buy } = body as RequestBody;
  if (!user_id || !kis_app_key || !kis_app_secret || !kis_account_no) {
    return json({ error: 'missing required fields (user_id, kis_app_key, kis_app_secret, kis_account_no)' }, 400);
  }

  // normalize daily_max_buy
  let dailyMax: number | null = null;
  if (daily_max_buy !== undefined && daily_max_buy !== null && daily_max_buy !== '') {
    const parsed = typeof daily_max_buy === 'string' ? parseInt(daily_max_buy, 10) : Number(daily_max_buy);
    if (!Number.isNaN(parsed) && parsed > 0) dailyMax = parsed;
  }

  // upsert into trading_configs for specified user_id (민감 필드는 암호화)
  let row: Record<string, unknown>;
  try {
    const kakao = await encryptField(notify_kakao_refresh_token);
    row = {
      user_id:                    user_id,
      broker_type:                broker_type || 'kis',
      kis_app_key:                await encryptField(kis_app_key),
      kis_app_secret:             await encryptField(kis_app_secret),
      kis_account_no:             await encryptField(kis_account_no),
      kis_account_prod_code:      kis_account_prod_code || '01',
      notify_email:               notify_email || null,
      notify_kakao_refresh_token: kakao,
      notify_kakao_active:        !!kakao,
      daily_max_buy:              dailyMax,
      is_active:                  true,
    };
  } catch (e) {
    // 암호화 실패를 삼키고 평문으로 저장하면 안 된다.
    console.error('encryption failed (admin):', e);
    return json({ error: 'server encryption not configured' }, 500);
  }

  const { error: dbErr } = await supabase
    .from('trading_configs')
    .upsert(row, { onConflict: 'user_id' });

  if (dbErr) {
    console.error('DB upsert failed (admin):', dbErr);
    return json({ error: 'DB upsert failed', detail: dbErr.message }, 500);
  }

  return json({ ok: true, saved: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
