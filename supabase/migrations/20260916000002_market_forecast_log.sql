-- ============================================================================
-- 시장 신호 적중률 추적
--
-- 문제: 매일 아침 메일이 "강세 N : 약세 M" 판정을 내보내는데, 그게 동전던지기보다
--       나은지 확인할 방법이 없었다. 판정도 결과도 어디에도 남지 않았다.
--
-- 이 테이블은 발송 시점의 판정(forecast)과 그날 장이 끝난 뒤의 실제 결과(outcome)를
-- 한 행에 모은다. trade_date = 그 판정이 겨냥한 거래일 (메일은 06:30에 나가므로 당일).
--
-- 접근: 서버(GitHub Actions, service_role)만 읽고 쓴다 → RLS ON + 정책 0개.
-- ============================================================================
CREATE TABLE IF NOT EXISTS market_forecast_log (
  trade_date          date PRIMARY KEY,

  -- ── 발송 시점의 판정 ──────────────────────────────────────────────────────
  verdict             text     NOT NULL,   -- 'bull' | 'bear' | 'neutral' (그룹 집계)
  bull                smallint NOT NULL DEFAULT 0,
  bear                smallint NOT NULL DEFAULT 0,
  neutral             smallint NOT NULL DEFAULT 0,
  -- 그룹화 이전의 개별 지표 카운트도 같이 남긴다. "상관 그룹으로 묶은 게 실제로
  -- 적중률을 높였나" 를 나중에 같은 데이터로 비교하기 위한 대조군이다.
  raw_verdict         text,
  raw_bull            smallint,
  raw_bear            smallint,
  signals_json        jsonb,               -- 그날 신호 원본 스냅샷

  -- ── 장 종료 후 채우는 실제 결과 ───────────────────────────────────────────
  kospi_prev_close    numeric,
  kospi_open          numeric,
  kospi_close         numeric,
  kosdaq_prev_close   numeric,
  kosdaq_open         numeric,
  kosdaq_close        numeric,
  -- gap  = 시가 / 전일종가 - 1  → 신호가 실제로 예측할 수 있는 구간
  -- close = 종가 / 전일종가 - 1 → 하루 전체
  kospi_gap_pct       numeric,
  kospi_close_pct     numeric,
  kosdaq_gap_pct      numeric,
  kosdaq_close_pct    numeric,
  outcome_filled_at   timestamptz,

  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_forecast_log_pending
  ON market_forecast_log (trade_date DESC)
  WHERE outcome_filled_at IS NULL;

ALTER TABLE market_forecast_log ENABLE ROW LEVEL SECURITY;
-- 정책 없음 = anon/authenticated 완전 차단, service_role 만 접근 (RLS 우회).
