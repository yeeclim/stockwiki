-- ============================================================================
-- 스크리닝 종목 관리 = 관리자 전용
--
-- 일반 사용자가 추가한 종목도 매일 스크리닝돼 전체 회원 메일·게시판에 실렸다.
-- 종목 추가/제외/복원은 서버(api/utils?type=admin-candidate, 관리자 확인 후 service_role)
-- 만 하도록 하고, 클라이언트의 직접 쓰기 권한을 모두 없앤다.
--
-- source 값
--   system : 광역 스캔(screen_broad.py)이 자동 선정·관리
--   admin  : 관리자가 수동 추가 (광역 스캔이 비활성화하지 않음)
--   user   : 과거 사용자 추가분 — 더 이상 스캔하지 않음 (적용 시점 0건)
--
-- 조회는 계속 공개한다 (테마 추천 화면의 "관리 종목" 분석이 목록을 읽는다).
-- ============================================================================

DROP POLICY IF EXISTS "사용자 종목 삽입" ON public.screening_candidates;
DROP POLICY IF EXISTS "사용자 종목 수정" ON public.screening_candidates;
DROP POLICY IF EXISTS "사용자 종목 삭제" ON public.screening_candidates;

DROP POLICY IF EXISTS "종목 조회" ON public.screening_candidates;
DROP POLICY IF EXISTS "시스템 종목 조회" ON public.screening_candidates;
CREATE POLICY "종목 조회" ON public.screening_candidates
  FOR SELECT USING (source IN ('system', 'admin', 'ai'));

-- RLS 정책이 없어도 테이블 권한 자체를 거둬 이중으로 막는다
REVOKE INSERT, UPDATE, DELETE ON public.screening_candidates FROM anon, authenticated;
