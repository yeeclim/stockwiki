-- ============================================================================
-- 적중률 로그에 장중 체크포인트 추가 (trading/INTRADAY_SIGNAL_PLAN.md 3-1)
--
-- 06:30 장전 판정 하나뿐이던 로그에, 장중(11시경) 같은 신호 로직으로 다시 낸 판정을
-- 같은 거래일의 별도 행으로 남긴다. "장전 판정 vs 장중 재판정 vs 실제 종가" 비교용.
--
-- checkpoint: 'pre' = 장전(06:30), 'mid' = 장중(11시경)
-- PK 가 trade_date → (trade_date, checkpoint) 로 바뀐다. 기존 행은 전부 'pre'.
--
-- 장중 판정을 전일종가 대비 종가(close_pct)로만 채점하면 체크포인트 이전에 이미
-- 일어난 움직임까지 '맞힌' 것으로 쳐서 적중률이 부풀려진다. 그래서 판정 시점의
-- 지수 레벨(*_at_check)을 같이 남기고, 그 이후 구간(*_rest_pct = 종가/체크포인트-1)
-- 으로 따로 채점한다. 장중 판정의 정직한 성적은 rest_pct 쪽이다.
-- ============================================================================
ALTER TABLE market_forecast_log
  ADD COLUMN IF NOT EXISTS checkpoint      text NOT NULL DEFAULT 'pre',
  ADD COLUMN IF NOT EXISTS recorded_at     timestamptz,   -- 실제 판정 시각 (Actions 지연 확인용)
  ADD COLUMN IF NOT EXISTS kospi_at_check  numeric,
  ADD COLUMN IF NOT EXISTS kosdaq_at_check numeric,
  ADD COLUMN IF NOT EXISTS kospi_rest_pct  numeric,
  ADD COLUMN IF NOT EXISTS kosdaq_rest_pct numeric;

ALTER TABLE market_forecast_log
  DROP CONSTRAINT IF EXISTS market_forecast_log_checkpoint_check;
ALTER TABLE market_forecast_log
  ADD CONSTRAINT market_forecast_log_checkpoint_check CHECK (checkpoint IN ('pre', 'mid'));

ALTER TABLE market_forecast_log DROP CONSTRAINT IF EXISTS market_forecast_log_pkey;
ALTER TABLE market_forecast_log ADD PRIMARY KEY (trade_date, checkpoint);
