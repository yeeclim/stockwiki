/**
 * Supabase Edge Function: save-trading-config
 *
 * Flutter 앱에서 사용자가 KIS API 키를 저장하면 호출됩니다.
 * trading_configs 에 민감 필드를 암호화해 upsert 합니다.
 *
 * 이전 이름은 register-to-github 였습니다 (2026-09-16 개명).
 * GitHub repository secrets 등록을 제거한 이유
 * -------------------------------------------
 * 예전엔 사용자 KIS 키를 USR_<uid>_* 라는 이름으로 GitHub repo secrets 에도
 * 넣었다. 그런데 그 시크릿을 읽는 코드가 어디에도 없었다 — trading.yml 은
 * 전역 KIS_APP_KEY 만 쓴다. 읽히지도 않는 자격증명을 public 저장소의 시크릿에
 * 복사해 두고, 그걸 위해 이 함수가 secrets:write 권한 PAT 을 들고 있었다.
 * 쓰지 않는 사본은 공격면일 뿐이라 통째로 걷어냈다.
 *
 * 암호화
 * ------
 * KIS App Key/Secret, 계좌번호, 카카오 refresh token 은 AES-256-GCM 으로
 * 암호화해 저장한다 (../_shared/crypto.ts). 복호화 키 TRADING_ENC_KEY 는
 * DB 밖(Function Secrets / GitHub Secrets)에 있으므로, DB 나 service_role 키가
 * 유출돼도 증권사 자격증명은 풀리지 않는다.
 *
 * Supabase Secrets:
 *   TRADING_ENC_KEY — base64 로 인코딩한 32바이트 (GitHub Secrets 와 동일 값)
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";
import { encryptField } from "../_shared/crypto.ts";

interface RequestBody {
  broker_type?:          string;
  kis_app_key?:          string;
  kis_app_secret?:       string;
  kis_account_no?:       string;
  kis_account_prod_code?: string;
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

  const {
    broker_type, kis_app_key, kis_app_secret, kis_account_no,
    kis_account_prod_code, notify_kakao_refresh_token, notify_email, daily_max_buy,
  } = body;

  // 자동매매 서버(trading/brokers)가 실제로 지원하는 증권사만 받는다.
  if (broker_type && broker_type !== "kis") {
    return json({ error: "현재 한국투자증권(KIS)만 지원합니다" }, 400);
  }

  // ── 기존 행 조회 ───────────────────────────────────────────────────────────
  // 앱이 저장된 키를 마스킹으로만 보여주므로(복호화해서 돌려주지 않는다), 사용자가
  // 한도만 바꾸고 저장하면 키 칸은 비어서 온다. 그때 빈 값으로 덮어쓰면 자동매매가
  // 죽는다. 새로 입력된 필드만 교체하고 나머지는 기존 암호문을 그대로 유지한다.
  const { data: existing } = await supabase
    .from("trading_configs")
    .select("kis_app_key, kis_app_secret, kis_account_no, kis_account_prod_code, notify_kakao_refresh_token, notify_kakao_active")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!existing && (!kis_app_key || !kis_app_secret || !kis_account_no)) {
    return json({ error: "필수 항목 누락 (App Key, App Secret, 계좌번호)" }, 400);
  }

  // normalize daily_max_buy (allow string or number)
  let dailyMax: number | null = null;
  if (daily_max_buy !== undefined && daily_max_buy !== null && daily_max_buy !== "") {
    const parsed = typeof daily_max_buy === "string" ? parseInt(daily_max_buy, 10) : Number(daily_max_buy);
    if (!Number.isNaN(parsed) && parsed > 0) dailyMax = parsed;
  }

  // 새 값이 있으면 암호화, 없으면 기존 암호문 유지
  const keep = async (fresh: string | undefined, stored: string | null | undefined) =>
    fresh ? await encryptField(fresh) : (stored ?? null);

  let row: Record<string, unknown>;
  try {
    const kakao = await keep(notify_kakao_refresh_token, existing?.notify_kakao_refresh_token);
    // 새 토큰을 넣었을 때만 알림을 켠다. 설정만 다시 저장했는데 꺼둔 알림이 되살아나면 안 된다.
    const kakaoActive = notify_kakao_refresh_token
      ? true
      : !!kakao && (existing?.notify_kakao_active ?? true);
    row = {
      user_id:                    user.id,
      broker_type:                "kis",
      kis_app_key:                await keep(kis_app_key,    existing?.kis_app_key),
      kis_app_secret:             await keep(kis_app_secret, existing?.kis_app_secret),
      kis_account_no:             await keep(kis_account_no, existing?.kis_account_no),
      kis_account_prod_code:      kis_account_prod_code || existing?.kis_account_prod_code || "01",
      notify_email:               notify_email || user.email || null,
      notify_kakao_refresh_token: kakao,
      notify_kakao_active:        kakaoActive,
      daily_max_buy:              dailyMax,
      is_active:                  true,
    };
  } catch (e) {
    // 암호화 실패(키 미설정 등)를 삼키고 평문으로 저장하면 안 된다.
    console.error("암호화 실패:", e);
    return json({ error: "서버 암호화 설정 오류 — 관리자에게 문의하세요" }, 500);
  }

  const { error: dbErr } = await supabase
    .from("trading_configs")
    .upsert(row, { onConflict: "user_id" });

  if (dbErr) {
    console.error("DB 저장 실패:", dbErr);
    return json({ error: "DB 저장 실패", detail: dbErr.message }, 500);
  }

  return json({ ok: true, saved: true });
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
