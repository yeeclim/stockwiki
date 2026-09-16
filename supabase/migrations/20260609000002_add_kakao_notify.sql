-- Add Kakao notify fields to trading_configs
ALTER TABLE trading_configs
  ADD COLUMN IF NOT EXISTS notify_kakao_refresh_token TEXT;

-- Optional: whether Kakao notify is enabled (defaults to false)
ALTER TABLE trading_configs
  ADD COLUMN IF NOT EXISTS notify_kakao_active BOOLEAN NOT NULL DEFAULT false;

-- No RLS changes needed: trading_configs already enforces "own row only" policies.
