-- strategy._score_entry가 이제 0.5점 단위 부분점수를 반환할 수 있어
-- score 컬럼을 INTEGER에서 NUMERIC으로 변경 (10점 만점 기준 소수점 1자리면 충분)
ALTER TABLE screening_results ALTER COLUMN score TYPE NUMERIC(4,1);
ALTER TABLE us_screening_results ALTER COLUMN score TYPE NUMERIC(4,1);
