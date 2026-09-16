-- 종목 스크리닝 결과 저장 테이블
-- screen.py 실행마다 upsert, main.py에서 최신 결과 상위 종목을 watchlist로 사용
CREATE TABLE IF NOT EXISTS screening_results (
  stock_code  TEXT        NOT NULL,
  stock_name  TEXT        NOT NULL,
  sector      TEXT,
  score       INTEGER     NOT NULL DEFAULT 0,
  price       INTEGER,
  pass        BOOLEAN     NOT NULL DEFAULT FALSE,
  screened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (stock_code)
);

ALTER TABLE screening_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service role full access" ON screening_results
  USING (TRUE) WITH CHECK (TRUE);
