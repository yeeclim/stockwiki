-- 사용자별 관심종목(북마크) — 로그인 계정에 귀속되어 기기 간 동기화됨
CREATE TABLE IF NOT EXISTS bookmarks (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stock_code     TEXT NOT NULL,
  stock_name     TEXT NOT NULL DEFAULT '',
  type           TEXT NOT NULL DEFAULT 'kr',
  price          DOUBLE PRECISION,
  change_percent DOUBLE PRECISION,
  change         DOUBLE PRECISION,
  bookmarked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, stock_code)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks (user_id, bookmarked_at DESC);

-- RLS: 자신의 행만 읽기/쓰기 가능
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "자신의 북마크만 조회" ON bookmarks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "자신의 북마크만 삽입" ON bookmarks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "자신의 북마크만 수정" ON bookmarks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "자신의 북마크만 삭제" ON bookmarks
  FOR DELETE USING (auth.uid() = user_id);
