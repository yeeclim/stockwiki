-- screen_broad.py 오류로 삭제된 시스템 종목 복원
-- screen_broad.py의 KRX API 400 오류로 인해 0건 조회 후 전체 삭제된 상황 복구

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
