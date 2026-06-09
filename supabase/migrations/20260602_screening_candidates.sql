-- 스크리닝 후보 종목 테이블
-- source: 'system' = 기본 제공, 'user' = 사용자 추가
CREATE TABLE IF NOT EXISTS screening_candidates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_code  TEXT NOT NULL,
  stock_name  TEXT NOT NULL,
  sector      TEXT NOT NULL,
  source      TEXT NOT NULL DEFAULT 'system',  -- 'system' | 'user'
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 같은 종목코드를 동일 유저가 중복 추가 방지 (user_id NULL = 시스템)
CREATE UNIQUE INDEX IF NOT EXISTS screening_candidates_unique
  ON screening_candidates (stock_code, COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::UUID));

-- RLS
ALTER TABLE screening_candidates ENABLE ROW LEVEL SECURITY;

-- 시스템 종목은 모든 로그인 유저가 조회 가능
CREATE POLICY "시스템 종목 조회" ON screening_candidates
  FOR SELECT USING (source = 'system' OR auth.uid() = user_id);

-- 사용자는 자신의 종목만 추가/수정/삭제
CREATE POLICY "사용자 종목 삽입" ON screening_candidates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "사용자 종목 수정" ON screening_candidates
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "사용자 종목 삭제" ON screening_candidates
  FOR DELETE USING (auth.uid() = user_id);

-- ── 기본 시스템 종목 삽입 ────────────────────────────────────────────────────
INSERT INTO screening_candidates (stock_code, stock_name, sector, source, user_id) VALUES
  -- 반도체
  ('005930', '삼성전자',       '반도체', 'system', NULL),
  ('000660', 'SK하이닉스',     '반도체', 'system', NULL),
  ('042700', '한미반도체',     '반도체', 'system', NULL),
  ('058470', '리노공업',       '반도체', 'system', NULL),
  ('036930', '주성엔지니어링', '반도체', 'system', NULL),
  ('000990', 'DB하이텍',       '반도체', 'system', NULL),
  ('064760', '두산테스나',     '반도체', 'system', NULL),
  ('240810', '원익IPS',        '반도체', 'system', NULL),
  ('140860', '파크시스템스',   '반도체', 'system', NULL),
  -- AI
  ('035420', 'NAVER',          'AI', 'system', NULL),
  ('035720', '카카오',         'AI', 'system', NULL),
  ('030200', 'KT',             'AI', 'system', NULL),
  ('017670', 'SK텔레콤',       'AI', 'system', NULL),
  ('181710', 'NHN',            'AI', 'system', NULL),
  ('095700', '제이씨현시스템', 'AI', 'system', NULL),
  -- 데이터센터
  ('093320', '케이아이엔엑스', '데이터센터', 'system', NULL),
  ('032640', 'LG유플러스',     '데이터센터', 'system', NULL),
  ('012510', '더존비즈온',     '데이터센터', 'system', NULL),
  ('079940', '가비아',         '데이터센터', 'system', NULL),
  ('018260', '삼성에스디에스', '데이터센터', 'system', NULL),
  -- 유리기판
  ('011790', 'SKC',            '유리기판', 'system', NULL),
  ('011070', 'LG이노텍',       '유리기판', 'system', NULL),
  ('009150', '삼성전기',       '유리기판', 'system', NULL),
  ('357780', '솔브레인',       '유리기판', 'system', NULL),
  -- 양자컴퓨터
  ('115440', '우리넷',         '양자컴퓨터', 'system', NULL),
  ('203650', '드림시큐리티',   '양자컴퓨터', 'system', NULL),
  ('056360', '코위버',         '양자컴퓨터', 'system', NULL),
  -- 클라우드
  ('234340', '틸론',           '클라우드', 'system', NULL),
  ('041510', '영림원소프트랩', '클라우드', 'system', NULL),
  ('294570', '쿠콘',           '클라우드', 'system', NULL),
  ('053580', '웹케시',         '클라우드', 'system', NULL),
  ('036570', '엔씨소프트',     '클라우드', 'system', NULL)
ON CONFLICT DO NOTHING;
