-- 자유게시판 게시글
CREATE TABLE IF NOT EXISTS board_posts (
  id            bigserial PRIMARY KEY,
  title         text        NOT NULL DEFAULT '',
  nickname      text        NOT NULL,
  content       text        NOT NULL,
  password_hash text        NOT NULL,
  ip_hash       text        NOT NULL,
  view_count    integer     NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_board_posts_created ON board_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_board_posts_ip      ON board_posts (ip_hash, created_at);

-- 댓글
CREATE TABLE IF NOT EXISTS board_comments (
  id            bigserial PRIMARY KEY,
  post_id       bigint      NOT NULL REFERENCES board_posts(id) ON DELETE CASCADE,
  nickname      text        NOT NULL,
  content       text        NOT NULL,
  password_hash text        NOT NULL,
  ip_hash       text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_board_comments_post ON board_comments (post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_board_comments_ip   ON board_comments (ip_hash, created_at);
