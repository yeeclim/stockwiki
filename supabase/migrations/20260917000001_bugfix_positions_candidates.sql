-- ============================================================================
-- 버그 수정 묶음 (2026-09-17)
--
-- 1) screening_candidates: 사용자가 source='system' 행을 직접 넣을 수 있던 구멍
--    INSERT/UPDATE 정책이 user_id 만 검사하고 source 는 검사하지 않았다.
--    'system' 은 SELECT 정책상 모든 사용자에게 보이므로, 한 사용자가 넣은 종목이
--    전체 화면·스크리닝에 섞여 들어갈 수 있었다. 사용자 행은 반드시 source='user'.
--
-- 2) trading_positions: 사용자별 포지션 분리
--    stock_code 하나로만 식별해서, 같은 종목을 가진 사용자끼리 물타기 완료
--    플래그를 공유했다. (user_id, stock_code) 로 유니크하게 만든다.
--    대시보드에서 만든 테이블이라 구조를 확신할 수 없어 전부 조건부로 처리한다.
--
-- 3) screening_results.market_cap: screen.py / ai_sector_picker.py 가 쓰는데
--    마이그레이션에 없던 컬럼.
-- ============================================================================

-- ── 1. screening_candidates 정책 ─────────────────────────────────────────────
DROP POLICY IF EXISTS "사용자 종목 삽입" ON public.screening_candidates;
DROP POLICY IF EXISTS "사용자 종목 수정" ON public.screening_candidates;

CREATE POLICY "사용자 종목 삽입" ON public.screening_candidates
  FOR INSERT WITH CHECK (auth.uid() = user_id AND source = 'user');

CREATE POLICY "사용자 종목 수정" ON public.screening_candidates
  FOR UPDATE USING (auth.uid() = user_id AND source = 'user')
  WITH CHECK (auth.uid() = user_id AND source = 'user');

-- 이미 들어가 있을 수 있는 "사용자 소유인데 system 으로 표시된" 행 정리
UPDATE public.screening_candidates
   SET source = 'user'
 WHERE source = 'system' AND user_id IS NOT NULL;

-- ── 2. trading_positions / trading_logs 사용자 분리 ─────────────────────────
DO $$
DECLARE
  pk_name text;
  pk_cols text[];
BEGIN
  IF to_regclass('public.trading_positions') IS NULL THEN
    RAISE NOTICE 'trading_positions 없음 — 건너뜀';
  ELSE
    ALTER TABLE public.trading_positions ADD COLUMN IF NOT EXISTS user_id uuid;

    -- PK 가 stock_code 단독이면 사용자별 행을 둘 수 없으므로 제거한다
    SELECT c.conname,
           array_agg(a.attname ORDER BY a.attnum)
      INTO pk_name, pk_cols
      FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
     WHERE c.conrelid = 'public.trading_positions'::regclass AND c.contype = 'p'
     GROUP BY c.conname;

    IF pk_name IS NOT NULL AND pk_cols = ARRAY['stock_code']::text[] THEN
      EXECUTE format('ALTER TABLE public.trading_positions DROP CONSTRAINT %I', pk_name);
      RAISE NOTICE 'trading_positions PK(stock_code) 제거';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
       WHERE conrelid = 'public.trading_positions'::regclass
         AND conname = 'trading_positions_user_stock_key'
    ) THEN
      -- NULLS NOT DISTINCT: user_id 가 없던 기존 행도 종목당 하나로 유지 (PG15+)
      ALTER TABLE public.trading_positions
        ADD CONSTRAINT trading_positions_user_stock_key
        UNIQUE NULLS NOT DISTINCT (user_id, stock_code);
    END IF;
  END IF;

  IF to_regclass('public.trading_logs') IS NOT NULL THEN
    ALTER TABLE public.trading_logs ADD COLUMN IF NOT EXISTS user_id uuid;
    CREATE INDEX IF NOT EXISTS idx_trading_logs_user_created
      ON public.trading_logs (user_id, created_at);
  END IF;
END $$;

-- ── 3. screening_results.market_cap ─────────────────────────────────────────
ALTER TABLE public.screening_results ADD COLUMN IF NOT EXISTS market_cap bigint;
