-- 미국 주식 스크리닝 결과 저장 테이블 (국내 screening_results와 동일 구조)
-- screen_us_broad.py 실행마다 upsert, api/us-recommend.js가 최신 결과를 읽어 사용
CREATE TABLE IF NOT EXISTS us_screening_results (
  stock_code      TEXT        NOT NULL,
  stock_name      TEXT        NOT NULL,
  sector          TEXT,
  score           INTEGER     NOT NULL DEFAULT 0,
  price           NUMERIC,
  market_cap_usd  BIGINT,
  pass            BOOLEAN     NOT NULL DEFAULT FALSE,
  screened_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (stock_code)
);

ALTER TABLE us_screening_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service role full access" ON us_screening_results
  USING (TRUE) WITH CHECK (TRUE);
