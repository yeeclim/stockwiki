-- ============================================================================
-- 운영 DB 스키마 드리프트 정리 (2026-09-17 전체 디버깅에서 발견)
--
-- 1) email_archive.brief_json 이 없다.
--    20260904000001 은 운영 이력에 "적용됨"으로 기록돼 있지만 컬럼이 실제로 없다.
--    screen.py 가 매번 저장 실패 → brief_json 없이 재저장하는 경로를 타서,
--    블로그 요약 카드용 지표가 계속 빠지고 있었다.
--
-- 2) screening_candidates 에 대시보드에서 만든 정책 allow_admin_or_owner_update 가 있다.
--    RLS 정책은 OR 로 합쳐지므로, 이 정책(WITH CHECK 없음) 때문에
--      - 사용자가 자기 행을 source='system' 으로 바꿀 수 있고
--        (20260917000001 에서 막은 구멍이 그대로 열려 있었다)
--      - 관리자 이메일이 레포 밖 정책에 하드코딩돼 있었다.
--    관리자 제외/복원은 이제 서버(api/utils?type=admin-candidate, service_role)가 처리하므로
--    이 정책은 필요 없다.
--
-- 3) trading_configs 는 클라이언트가 본인 행을 직접 INSERT/UPDATE 할 수 있었다.
--    그러면 암호화·증권사 검증을 하는 save-trading-config 함수를 우회해 평문 키나
--    지원하지 않는 broker_type 을 넣을 수 있다. 앱이 직접 쓰는 건 자동매매 끄기
--    (is_active=false) 하나뿐이므로 그 컬럼만 남긴다. 저장은 Edge Function(service_role).
-- ============================================================================

-- ── 1 ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.email_archive ADD COLUMN IF NOT EXISTS brief_json jsonb;

-- ── 2 ───────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "allow_admin_or_owner_update" ON public.screening_candidates;

-- ── 3 ───────────────────────────────────────────────────────────────────────
REVOKE INSERT, UPDATE ON public.trading_configs FROM anon, authenticated;
GRANT UPDATE (is_active) ON public.trading_configs TO authenticated;
