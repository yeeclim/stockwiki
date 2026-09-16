-- board_posts RLS
ALTER TABLE board_posts ENABLE ROW LEVEL SECURITY;

-- 누구나 읽기 가능
CREATE POLICY "board_posts_select" ON board_posts
  FOR SELECT USING (true);

-- 쓰기는 service_role만 (API 서버에서만 가능, 직접 접근 차단)
-- INSERT/UPDATE/DELETE 정책 없음 → anon/authenticated 차단됨
-- (service_role 키는 RLS를 우회하므로 api/board.js는 정상 동작)

-- board_comments RLS
ALTER TABLE board_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "board_comments_select" ON board_comments
  FOR SELECT USING (true);
