-- 스크리닝 판정 근거 저장 — 앱 투자 포인트가 실제 선정 기준(strategy._score_entry)을
-- 그대로 보여주도록 한다. 예전엔 앱이 별도 JS 로직으로 차트를 설명해, 선정 기준
-- (현재가 < 60일선)과 반대인 "60일선 10.5% 상회 — 중기 상승 추세"가 붙었다(2026-10-14 HMM).
ALTER TABLE public.screening_results
  ADD COLUMN IF NOT EXISTS verdict        text,    -- pass | below_score | news_negative | news_unanalyzed
  ADD COLUMN IF NOT EXISTS reasons        text[],  -- 항목별 채점 로그 (✅/❌/⛔/⚠️ 한 줄씩)
  ADD COLUMN IF NOT EXISTS sentiment_line text;    -- 뉴스 감성 한 줄
