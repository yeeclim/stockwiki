/**
 * Supabase Edge Function: delete-account
 *
 * 로그인한 사용자가 스스로 계정을 삭제(회원 탈퇴)할 때 호출됩니다.
 * 1. JWT 로 사용자 인증
 * 2. auth.users 삭제 → bookmarks / trading_configs / screening_candidates 는
 *    ON DELETE CASCADE 로 함께 삭제됨
 *
 * USR_<uid>_* GitHub repo secrets 정리 단계가 있었으나, 그 시크릿을 만드는
 * 경로(save-trading-config, 당시 이름 register-to-github)를 제거하면서 함께 걷어냈다. 읽는 코드가 없는 사본을
 * public 저장소 시크릿에 두던 구조라, 만들지도 지우지도 않는 쪽이 맞다.
 *
 * Supabase Secrets:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  — 자동 주입
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, x-client-info, apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ── 인증 ────────────────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  const { data: { user }, error: authErr } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (authErr || !user) return json({ error: "인증 실패" }, 401);

  // ── 1. 남아있을 수 있는 사용자 데이터 명시적 삭제 (CASCADE 백업) ─────────────
  await supabase.from("trading_configs").delete().eq("user_id", user.id);
  await supabase.from("bookmarks").delete().eq("user_id", user.id);
  await supabase.from("screening_candidates").delete().eq("user_id", user.id);

  // ── 2. 계정 삭제 ───────────────────────────────────────────────────────────
  const { error: delErr } = await supabase.auth.admin.deleteUser(user.id);
  if (delErr) {
    console.error("계정 삭제 실패:", delErr);
    return json({ error: "계정 삭제 실패", detail: delErr.message }, 500);
  }

  return json({ ok: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
