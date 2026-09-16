-- ============================================================================
-- RLS 보안 강화 (Supabase Security Advisor: rls_disabled_in_public 대응)
--
-- 배경: 마이그레이션 없이 대시보드에서 직접 만든 테이블(trading_positions,
--       trading_logs, trading_watchlist)에 RLS가 꺼져 있어, anon 키만으로
--       누구나 읽기/수정/삭제가 가능한 상태였다.
--       추가로 기존 정책 중 "service role full access"라는 이름과 달리
--       실제로는 public(anon+authenticated) 역할에 ALL 권한을 열어준
--       정책들이 있어 함께 정리한다.
--
-- 원칙: service_role 키는 RLS를 우회하므로, 서버(Vercel api/*, GitHub Actions
--       trading/*)에서만 접근하는 테이블은 "RLS ON + 정책 0개"가 정답이다.
--       Flutter 클라이언트가 anon 키로 직접 접근하는 테이블
--       (bookmarks / screening_candidates / trading_configs)만 정책을 둔다.
-- ============================================================================

-- ── 1. RLS가 꺼진 public 테이블 전부 활성화 ──────────────────────────────────
-- 이름을 열거하지 않고 동적으로 처리해 대시보드에서 만든 미지의 테이블까지 덮는다.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'          -- 일반 테이블만 (뷰/파티션 제외)
      AND NOT c.relrowsecurity
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.relname);
    RAISE NOTICE 'RLS enabled: public.%', r.relname;
  END LOOP;
END $$;

-- ── 2. public 역할에 ALL을 열어둔 잘못된 정책 제거 ───────────────────────────
-- USING(TRUE) WITH CHECK(TRUE) + TO 절 없음 = anon/authenticated 모두에게
-- SELECT/INSERT/UPDATE/DELETE 허용. 이름만 "service role"이었다.
-- 두 테이블 모두 서버(service_role)에서만 읽고 쓰므로 정책 자체가 불필요하다.
DROP POLICY IF EXISTS "service role full access" ON public.screening_results;
DROP POLICY IF EXISTS "service role full access" ON public.us_screening_results;

-- ── 3. 게시판: anon 직접 조회 차단 ───────────────────────────────────────────
-- board_posts/board_comments 에는 password_hash, ip_hash 컬럼이 있는데
-- RLS는 행 단위라 SELECT를 열면 이 컬럼들도 그대로 노출된다.
-- 프론트엔드는 /api/board, /api/board_comments (service_role)만 호출하므로
-- anon 직접 조회를 열어둘 이유가 없다.
DROP POLICY IF EXISTS "board_posts_select"    ON public.board_posts;
DROP POLICY IF EXISTS "board_comments_select" ON public.board_comments;

-- ── 4. 확인용 ────────────────────────────────────────────────────────────────
-- 적용 후 아래 쿼리로 검증:
--   SELECT c.relname, c.relrowsecurity,
--          COALESCE(string_agg(p.polname || '=' || p.polcmd::text, ', '), '(정책 없음)')
--   FROM pg_class c
--   JOIN pg_namespace n ON n.oid = c.relnamespace
--   LEFT JOIN pg_policy p ON p.polrelid = c.oid
--   WHERE n.nspname = 'public' AND c.relkind = 'r'
--   GROUP BY 1, 2 ORDER BY 2, 1;
