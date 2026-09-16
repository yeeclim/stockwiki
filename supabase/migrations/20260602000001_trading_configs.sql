-- 사용자별 KIS API 설정 테이블
CREATE TABLE IF NOT EXISTS trading_configs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kis_app_key           TEXT NOT NULL,
  kis_app_secret        TEXT NOT NULL,
  kis_account_no        TEXT NOT NULL,
  kis_account_prod_code TEXT NOT NULL DEFAULT '01',
  notify_email          TEXT,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  github_registered_at  TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

-- 수정 시 updated_at 자동 갱신
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trading_configs_updated_at ON trading_configs;
CREATE TRIGGER trading_configs_updated_at
  BEFORE UPDATE ON trading_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: 자신의 행만 읽기/쓰기 가능
ALTER TABLE trading_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "자신의 설정만 조회" ON trading_configs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "자신의 설정만 삽입" ON trading_configs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "자신의 설정만 수정" ON trading_configs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "자신의 설정만 삭제" ON trading_configs
  FOR DELETE USING (auth.uid() = user_id);

-- service_role은 RLS 우회 (trading 스크립트용)
-- (service_role key 사용 시 자동으로 bypass됨)
