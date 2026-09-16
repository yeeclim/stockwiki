-- Add daily max buy column to trading_configs
ALTER TABLE trading_configs
  ADD COLUMN IF NOT EXISTS daily_max_buy BIGINT;

-- Default is NULL (no user preference). The strategy will fall back to a global cap when NULL.
