-- Yahoo assetProfile에서 가져오는 GICS 대분류 섹터(Technology/Healthcare/...) 저장.
-- 기존 sector 컬럼은 상장 거래소(NASDAQ/NYSE/AMEX) 의미로 계속 사용되므로 건드리지 않음
-- (api/us-recommend.js가 exchange 표시용으로 그대로 사용 중).
-- screen_us_broad.py가 top-60 후보에 한해서만 채워 넣으므로 NULL 허용.
ALTER TABLE us_screening_results ADD COLUMN IF NOT EXISTS gics_sector TEXT;
