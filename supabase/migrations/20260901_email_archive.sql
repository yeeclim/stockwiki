-- 실제 발송된 스크리닝 메일의 HTML/텍스트 원본 보관
-- (블로그 등 다른 채널에 "메일과 100% 동일한 내용"을 옮길 때 이 테이블에서 가져온다)
CREATE TABLE IF NOT EXISTS email_archive (
  id         bigserial PRIMARY KEY,
  subject    text        NOT NULL,
  html       text        NOT NULL,
  plain_text text        NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_archive_created ON email_archive (created_at DESC);

ALTER TABLE email_archive ENABLE ROW LEVEL SECURITY;

-- 누구나 읽기 가능 (board_posts와 동일 정책 — anon key로 로컬 스크립트에서 조회)
CREATE POLICY "email_archive_select" ON email_archive
  FOR SELECT USING (true);

-- 쓰기는 service_role만 (screen.py가 GitHub Actions에서 저장)
