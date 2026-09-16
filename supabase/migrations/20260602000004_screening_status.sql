-- screening_candidates에 AI 추천 상태 컬럼 추가
ALTER TABLE screening_candidates
  ADD COLUMN IF NOT EXISTS status    TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS ai_reason TEXT;

-- status: 'approved' = 노출됨 | 'ai_pending' = AI 추천 검토 대기 | 'rejected' = 거절됨
-- 기존 rows는 모두 approved
UPDATE screening_candidates SET status = 'approved' WHERE status IS NULL OR status = '';
