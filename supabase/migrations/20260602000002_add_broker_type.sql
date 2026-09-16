-- broker_type: 'kis' | 'kiwoom' | 'nh' | 'samsung'
ALTER TABLE trading_configs
  ADD COLUMN IF NOT EXISTS broker_type TEXT NOT NULL DEFAULT 'kis';

-- 기존 행은 모두 KIS
UPDATE trading_configs SET broker_type = 'kis' WHERE broker_type IS NULL OR broker_type = '';
