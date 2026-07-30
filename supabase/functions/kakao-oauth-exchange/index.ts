/**
 * Supabase Edge Function: kakao-oauth-exchange
 *
 * Flutter 앱에서 사용자가 "카카오 알림 연동하기" 버튼으로 카카오 로그인을
 * 마치고 돌아오면(인가 코드 획득) 호출됩니다.
 * 1. 인가 코드를 카카오 서버에서 access_token/refresh_token으로 교환
 * 2. trading_configs.notify_kakao_refresh_token 갱신
 *
 * Supabase Secrets (supabase secrets set 으로 등록):
 *   KAKAO_REST_API_KEY  — StockWiki 카카오 앱의 REST API 키 (client_id)
 *   KAKAO_CLIENT_SECRET — 위 앱의 카카오 로그인용 클라이언트 시크릿
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

const KAKAO_REST_API_KEY  = Deno.env.get("KAKAO_REST_API_KEY")  ?? "";
const KAKAO_CLIENT_SECRET = Deno.env.get("KAKAO_CLIENT_SECRET") ?? "";
const KAKAO_REDIRECT_URI  = "https://stockwiki.vercel.app";

interface RequestBody {
  code?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type, x-client-info, apikey",
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

  const { code } = body;
  if (!code) {
    return json({ error: "인가 코드(code)가 필요합니다" }, 400);
  }

  if (!KAKAO_REST_API_KEY || !KAKAO_CLIENT_SECRET) {
    return json({ error: "서버에 카카오 앱 설정이 없습니다" }, 500);
  }

  // ── 1. 카카오 인가 코드 → 토큰 교환 ─────────────────────────────────────────
  const tokenRes = await fetch("https://kauth.kakao.com/oauth/token", {
    method:  "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type:    "authorization_code",
      client_id:     KAKAO_REST_API_KEY,
      client_secret: KAKAO_CLIENT_SECRET,
      redirect_uri:  KAKAO_REDIRECT_URI,
      code,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenRes.ok || !tokenData.refresh_token) {
    console.error("카카오 토큰 교환 실패:", tokenData);
    return json({ error: "카카오 인증에 실패했습니다", detail: tokenData }, 400);
  }

  // ── 2. trading_configs 갱신 (기존 행이 있을 때만 — kis_* 컬럼이 NOT NULL) ───
  const { data, error: dbErr } = await supabase
    .from("trading_configs")
    .update({
      notify_kakao_refresh_token: tokenData.refresh_token,
      notify_kakao_active:        true,
    })
    .eq("user_id", user.id)
    .select("id");

  if (dbErr) {
    console.error("DB 갱신 실패:", dbErr);
    return json({ error: "DB 저장 실패", detail: dbErr.message }, 500);
  }
  if (!data || data.length === 0) {
    return json({ error: "먼저 증권사 API 설정을 저장해주세요" }, 409);
  }

  return json({ ok: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type":                "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
