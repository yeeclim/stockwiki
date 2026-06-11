/**
 * Supabase Edge Function: register-to-github
 *
 * Flutter 앱에서 사용자가 KIS API 키를 저장하면 호출됩니다.
 * 1. trading_configs 테이블에 키를 upsert
 * 2. GitHub REST API로 repository secrets 자동 등록
 *
 * Supabase Secrets (supabase secrets set 으로 등록):
 *   GITHUB_TOKEN     — repo secrets 쓰기 권한을 가진 PAT
 *   GITHUB_OWNER     — 레포지토리 소유자 (예: bermont)
 *   GITHUB_REPO      — 레포지토리 이름 (예: stockwiki)
 */
// Use the ESM CDN build which works reliably in Deno/Supabase Edge Functions
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";
import * as base64 from "jsr:@std/encoding/base64";
import sodium from "npm:libsodium-wrappers";

const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN") ?? "";
const GITHUB_OWNER = Deno.env.get("GITHUB_OWNER") ?? "";
const GITHUB_REPO  = Deno.env.get("GITHUB_REPO")  ?? "";

interface RequestBody {
  broker_type?:          string;
  kis_app_key:           string;
  kis_app_secret:        string;
  kis_account_no:        string;
  kis_account_prod_code: string;
  notify_kakao_refresh_token?: string;
  notify_email?:         string;
  daily_max_buy?:        number | string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  // ── 인증: JWT에서 user_id 추출 ─────────────────────────────────────────────
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const authHeader = req.headers.get("Authorization") ?? "";
  const { data: { user }, error: authErr } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (authErr || !user) {
    return json({ error: "인증 실패" }, 401);
  }

  // ── 요청 파싱 ──────────────────────────────────────────────────────────────
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "잘못된 요청 본문" }, 400);
  }

  const { broker_type, kis_app_key, kis_app_secret, kis_account_no, kis_account_prod_code, notify_kakao_refresh_token, notify_email, daily_max_buy } = body;
  if (!kis_app_key || !kis_app_secret || !kis_account_no) {
    return json({ error: "필수 항목 누락 (App Key, App Secret, 계좌번호)" }, 400);
  }

  // normalize daily_max_buy (allow string or number)
  let dailyMax: number | null = null;
  if (daily_max_buy !== undefined && daily_max_buy !== null && daily_max_buy !== '') {
    const parsed = typeof daily_max_buy === 'string' ? parseInt(daily_max_buy, 10) : Number(daily_max_buy);
    if (!Number.isNaN(parsed) && parsed > 0) dailyMax = parsed;
  }

  // ── 1. Supabase DB에 저장 ──────────────────────────────────────────────────
  const { error: dbErr } = await supabase
    .from("trading_configs")
    .upsert({
      user_id:                       user.id,
      broker_type:                   broker_type || "kis",
      kis_app_key,
      kis_app_secret,
      kis_account_no,
      kis_account_prod_code:         kis_account_prod_code || "01",
      notify_email:                  notify_email || user.email || null,
      notify_kakao_refresh_token:    notify_kakao_refresh_token || null,
      notify_kakao_active:           !!notify_kakao_refresh_token,
      daily_max_buy:                 dailyMax,
      is_active:                     true,
    }, { onConflict: "user_id" });

  if (dbErr) {
    console.error("DB 저장 실패:", dbErr);
    return json({ error: "DB 저장 실패", detail: dbErr.message }, 500);
  }

  // ── 2. GitHub API로 repository secrets 등록 ────────────────────────────────
  if (!GITHUB_TOKEN || !GITHUB_OWNER || !GITHUB_REPO) {
    console.warn("GitHub 환경변수 미설정 — DB 저장만 완료");
    return json({ ok: true, github: false, message: "DB 저장 완료 (GitHub 미설정)" });
  }

  try {
    await sodium.ready;

    // 레포 공개키 조회
    const pkRes = await fetch(
      `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets/public-key`,
      { headers: githubHeaders() },
    );
    if (!pkRes.ok) throw new Error(`공개키 조회 실패: ${pkRes.status}`);
    const { key, key_id } = await pkRes.json();

    // 사용자 id prefix로 구분 (최대 40자, 영숫자+언더스코어)
    const uid = user.id.replace(/-/g, "_").substring(0, 20);

    const secrets: Record<string, string> = {
      [`USR_${uid}_KIS_APP_KEY`]:           kis_app_key,
      [`USR_${uid}_KIS_APP_SECRET`]:        kis_app_secret,
      [`USR_${uid}_KIS_ACCOUNT_NO`]:        kis_account_no,
      [`USR_${uid}_KIS_ACCOUNT_PROD_CODE`]: kis_account_prod_code || "01",
      [`USR_${uid}_NOTIFY_EMAIL`]:          notify_email || user.email || "",
      // optional daily max buy as repo secret (stringified)
      [`USR_${uid}_DAILY_MAX_BUY`]:         dailyMax ? String(dailyMax) : "",
    };

    const results: Record<string, boolean> = {};
    for (const [name, value] of Object.entries(secrets)) {
      const encrypted = encryptSecret(sodium, key, value);
      const r = await fetch(
        `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets/${name}`,
        {
          method:  "PUT",
          headers: githubHeaders(),
          body:    JSON.stringify({ encrypted_value: encrypted, key_id }),
        },
      );
      results[name] = r.ok;
      if (!r.ok) console.error(`시크릿 등록 실패 [${name}]:`, r.status, await r.text());
    }

    // github_registered_at 갱신
    await supabase
      .from("trading_configs")
      .update({ github_registered_at: new Date().toISOString() })
      .eq("user_id", user.id);

    return json({ ok: true, github: true, secrets: results });
  } catch (e) {
    console.error("GitHub 등록 오류:", e);
    return json({ ok: true, github: false, message: String(e) });
  }
});

// ── 헬퍼 ────────────────────────────────────────────────────────────────────

function githubHeaders() {
  return {
    "Authorization": `Bearer ${GITHUB_TOKEN}`,
    "Accept":        "application/vnd.github+json",
    "Content-Type":  "application/json",
    "X-GitHub-Api-Version": "2022-11-28",
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
      "Content-Type":                "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
