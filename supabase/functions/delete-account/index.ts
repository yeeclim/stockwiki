/**
 * Supabase Edge Function: delete-account
 *
 * 로그인한 사용자가 스스로 계정을 삭제(회원 탈퇴)할 때 호출됩니다.
 * 1. JWT 로 사용자 인증
 * 2. (선택) GitHub repository 에 등록된 이 사용자 전용 secrets(USR_<uid>_*) 제거
 * 3. auth.users 삭제 → bookmarks / trading_configs / screening_candidates 는
 *    ON DELETE CASCADE 로 함께 삭제됨
 *
 * Supabase Secrets:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  — 자동 주입
 *   GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO  — 선택 (자동매매 등록했던 사용자 정리용)
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN") ?? "";
const GITHUB_OWNER = Deno.env.get("GITHUB_OWNER") ?? "";
const GITHUB_REPO  = Deno.env.get("GITHUB_REPO")  ?? "";

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

  // ── 1. GitHub 사용자 전용 secrets 정리 (best-effort) ────────────────────────
  let githubCleaned = 0;
  if (GITHUB_TOKEN && GITHUB_OWNER && GITHUB_REPO) {
    try {
      const uid = user.id.replace(/-/g, "_").substring(0, 20);
      const prefix = `USR_${uid}_`;
      const listRes = await fetch(
        `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets?per_page=100`,
        { headers: githubHeaders() },
      );
      if (listRes.ok) {
        const { secrets = [] } = await listRes.json();
        for (const s of secrets as Array<{ name: string }>) {
          if (!s.name.startsWith(prefix)) continue;
          const d = await fetch(
            `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/secrets/${s.name}`,
            { method: "DELETE", headers: githubHeaders() },
          );
          if (d.ok) githubCleaned++;
        }
      }
    } catch (e) {
      console.error("GitHub secrets 정리 실패:", e);
    }
  }

  // ── 2. 남아있을 수 있는 사용자 데이터 명시적 삭제 (CASCADE 백업) ─────────────
  await supabase.from("trading_configs").delete().eq("user_id", user.id);
  await supabase.from("bookmarks").delete().eq("user_id", user.id);
  await supabase.from("screening_candidates").delete().eq("user_id", user.id);

  // ── 3. 계정 삭제 ───────────────────────────────────────────────────────────
  const { error: delErr } = await supabase.auth.admin.deleteUser(user.id);
  if (delErr) {
    console.error("계정 삭제 실패:", delErr);
    return json({ error: "계정 삭제 실패", detail: delErr.message }, 500);
  }

  return json({ ok: true, github_secrets_removed: githubCleaned });
});

function githubHeaders() {
  return {
    "Authorization": `Bearer ${GITHUB_TOKEN}`,
    "Accept":        "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
