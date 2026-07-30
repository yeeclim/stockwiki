/**
 * Supabase Edge Function: admin-register-to-github
 *
 * Allows a trusted operator (with ADMIN_API_KEY) to upsert `trading_configs`
 * for any `user_id`. This is intended for administrative workflows only.
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";
import * as base64 from "jsr:@std/encoding/base64";
import sodium from "npm:libsodium-wrappers";

const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN") ?? "";
const GITHUB_OWNER = Deno.env.get("GITHUB_OWNER") ?? "";
const GITHUB_REPO  = Deno.env.get("GITHUB_REPO")  ?? "";
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

  // upsert into trading_configs for specified user_id
  const { error: dbErr } = await supabase
    .from('trading_configs')
    .upsert({
      user_id:                       user_id,
      broker_type:                   broker_type || 'kis',
      kis_app_key,
      kis_app_secret,
      kis_account_no,
      kis_account_prod_code:         kis_account_prod_code || '01',
      notify_email:                  notify_email || null,
      notify_kakao_refresh_token:    notify_kakao_refresh_token || null,
      notify_kakao_active:           !!notify_kakao_refresh_token,
      daily_max_buy:                 dailyMax,
      is_active:                     true,
    }, { onConflict: 'user_id' });

  if (dbErr) {
    console.error('DB upsert failed (admin):', dbErr);
    return json({ error: 'DB upsert failed', detail: dbErr.message }, 500);
  }

  // Optionally register as GitHub repo secrets (if configured)
  if (!GITHUB_TOKEN || !GITHUB_OWNER || !GITHUB_REPO) {
    return json({ ok: true, github: false, message: 'DB upsert complete (GitHub not configured)' });
  }

  try {
    await sodium.ready;

    const pkRes = await fetch(
      `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets/public-key`,
      { headers: githubHeaders() },
    );
    if (!pkRes.ok) throw new Error(`public key fetch failed: ${pkRes.status}`);
    const { key, key_id } = await pkRes.json();

    const uid = user_id.replace(/-/g, '_').substring(0, 20);
    const secrets: Record<string, string> = {
      [`USR_${uid}_KIS_APP_KEY`]:           kis_app_key,
      [`USR_${uid}_KIS_APP_SECRET`]:        kis_app_secret,
      [`USR_${uid}_KIS_ACCOUNT_NO`]:        kis_account_no,
      [`USR_${uid}_KIS_ACCOUNT_PROD_CODE`]: kis_account_prod_code || '01',
      [`USR_${uid}_NOTIFY_EMAIL`]:          notify_email || '',
      [`USR_${uid}_DAILY_MAX_BUY`]:         dailyMax ? String(dailyMax) : '',
      [`USR_${uid}_NOTIFY_KAKAO_REFRESH_TOKEN`]: notify_kakao_refresh_token || '',
    };

    const results: Record<string, boolean> = {};
    for (const [name, value] of Object.entries(secrets)) {
      const encrypted = encryptSecret(sodium, key, value);
      const r = await fetch(
        `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets/${name}`,
        {
          method: 'PUT',
          headers: githubHeaders(),
          body: JSON.stringify({ encrypted_value: encrypted, key_id }),
        },
      );
      results[name] = r.ok;
      if (!r.ok) console.error(`secret set failed [${name}]:`, r.status, await r.text());
    }

    // update github_registered_at
    await supabase
      .from('trading_configs')
      .update({ github_registered_at: new Date().toISOString() })
      .eq('user_id', user_id);

    return json({ ok: true, github: true, secrets: results });
  } catch (e) {
    console.error('GitHub registration error (admin):', e);
    return json({ ok: true, github: false, message: String(e) });
  }
});

function githubHeaders() {
  return {
    'Authorization': `Bearer ${GITHUB_TOKEN}`,
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
}

function encryptSecret(sod: typeof sodium, publicKeyB64: string, secretValue: string): string {
  const keyBytes    = sod.from_base64(publicKeyB64, sod.base64_variants.ORIGINAL);
  const secretBytes = new TextEncoder().encode(secretValue);
  const encrypted   = sod.crypto_box_seal(secretBytes, keyBytes);
  return base64.encodeBase64(encrypted);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
