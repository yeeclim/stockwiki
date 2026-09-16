-- 블로그 요약 카드 이미지 생성을 위해, 메일과 함께 계산된 요약 지표(brief) 원본을 보관.
-- (naver_blog_local.py 가 로컬 헤드리스 Chrome으로 카드 PNG를 렌더링할 때 사용)
ALTER TABLE email_archive ADD COLUMN IF NOT EXISTS brief_json jsonb;
