
class KrxLoader {
  // 테마별 추천 종목 데이터 (주달 기준 상위 10개 테마)
  static const Map<String, List<Map<String, dynamic>>> _themeStocks = {
    '2차전지': [
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '2차전지', 
        'marketCap': 45000000000000, 
        'description': '2차전지 소재 및 시스템',
        'reason': '전고체 배터리 기술 선도 및 프리미엄 EV 시장 점유율 확대 기대',
        'news': [
          {'title': '삼성SDI, 전고체 배터리 파일럿 라인 가동... "꿈의 배터리" 양산 박차', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+전고체+배터리'},
          {'title': 'BMW·아우디 등 유럽 프리미엄 전기차에 삼성 배터리 탑재 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+BMW+아우디'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '2차전지', 
        'marketCap': 38000000000000, 
        'description': '배터리 소재',
        'reason': '양극재 내재화율 상승 및 글로벌 배터리 소재 공급망 강화',
        'news': [
          {'title': 'LG화학, 미국 테네시 양극재 공장 착공... 북미 최대 규모', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+테네시+양극재'},
          {'title': '도요타와 2.8조 양극재 공급 계약... 일본 시장 본격 진출', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+도요타+양극재'}
        ]
      },
      {
        'symbol': '003670', 
        'name': '포스코홀딩스', 
        'sector': '2차전지', 
        'marketCap': 28000000000000, 
        'description': '배터리 소재',
        'reason': '리튬 염호 보유로 원자재 밸류체인 수직 계열화 성공',
        'news': [
          {'title': '포스코홀딩스, 아르헨티나 리튬 염호 2단계 투자 확정', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코홀딩스+리튬+염호'},
          {'title': '친환경 니켈 제련 기술 확보... 2차전지 소재 풀밸류체인 완성', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코홀딩스+니켈+제련'}
        ]
      },
      {
        'symbol': '000270', 
        'name': '기아', 
        'sector': '2차전지', 
        'marketCap': 25000000000000, 
        'description': '전기차 제조',
        'reason': 'E-GMP 기반 전용 전기차 라인업 확대로 글로벌 시장 입지 강화',
        'news': [
          {'title': '기아 EV9, "북미 올해의 차" 유력 후보 선정', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+EV9+북미+올해의차'},
          {'title': '글로벌 전기차 판매 50만대 돌파... 수익성 중심 성장 가속', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+전기차+판매'}
        ]
      },
      {
        'symbol': '005380', 
        'name': '현대차', 
        'sector': '2차전지', 
        'marketCap': 22000000000000, 
        'description': '전기차 제조',
        'reason': '전동화 전환 가속화 및 미국 조지아 전기차 전용 공장 가동 기대',
        'news': [
          {'title': '현대차, 울산 전기차 전용 공장 기공식... 2조원 투자', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+울산+전기차공장'},
          {'title': '아이오닉5 N, "탑기어" 선정 올해의 차 수상', 'url': 'https://search.naver.com/search.naver?where=news&query=아이오닉5N+탑기어'}
        ]
      },
    ],
    '반도체장비': [
      {
        'symbol': '000660', 
        'name': 'SK하이닉스', 
        'sector': '반도체장비', 
        'marketCap': 55000000000000, 
        'description': '메모리 반도체',
        'reason': 'HBM(고대역폭 메모리) 시장 독보적 점유율로 AI 반도체 수혜 집중',
        'news': [
          {'title': 'SK하이닉스, HBM3E 세계 최초 양산 시작... 엔비디아 공급', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+HBM3E'},
          {'title': 'AI 반도체 수요 폭증에 낸드 흑자 전환 기대감', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+낸드+흑자'}
        ]
      },
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': '반도체장비', 
        'marketCap': 45000000000000, 
        'description': '시스템 반도체',
        'reason': '메모리 반도체 업황 회복 및 파운드리 부문 성장 잠재력',
        'news': [
          {'title': '삼성전자, 업계 최초 12단 HBM3E 개발 성공', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+12단+HBM3E'},
          {'title': '갤럭시 S24 "온디바이스 AI" 호평... 반도체 부문 실적 견인', 'url': 'https://search.naver.com/search.naver?where=news&query=갤럭시S24+온디바이스AI'}
        ]
      },
      {
        'symbol': '240810', 
        'name': '원익IPS', 
        'sector': '반도체장비', 
        'marketCap': 8000000000000, 
        'description': '반도체 장비',
        'reason': '삼성전자 설비 투자 재개 시 전공정 장비 수주 확대 예상',
        'news': [
          {'title': '반도체 미세공정 확대... 원익IPS 증착 장비 수요 증가', 'url': 'https://search.naver.com/search.naver?where=news&query=원익IPS+반도체+장비'},
          {'title': '삼성전자 평택 캠퍼스 투자 재개 조짐... 장비주 반등 기대', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+평택+투자'}
        ]
      },
      {
        'symbol': '095610', 
        'name': '테스', 
        'sector': '반도체장비', 
        'marketCap': 5000000000000, 
        'description': '반도체 테스트 장비',
        'reason': '3D NAND 고단화에 따른 증착 장비 수요 증가 수혜',
        'news': [
          {'title': 'SK하이닉스 낸드 투자 확대... 테스 장비 수주 잇따라', 'url': 'https://search.naver.com/search.naver?where=news&query=테스+SK하이닉스+장비'},
          {'title': '반도체 업황 바닥 통과... 후공정 장비 리드타임 증가', 'url': 'https://search.naver.com/search.naver?where=news&query=반도체+후공정+장비'}
        ]
      },
      {
        'symbol': '042700', 
        'name': '한미반도체', 
        'sector': '반도체장비', 
        'marketCap': 9000000000000, 
        'description': '반도체 장비',
        'reason': 'HBM 생산 필수 장비인 TC본더 글로벌 점유율 1위',
        'news': [
          {'title': '한미반도체, 마이크론과 226억 규모 장비 공급 계약', 'url': 'https://search.naver.com/search.naver?where=news&query=한미반도체+마이크론'},
          {'title': 'HBM 시장 확대로 "TC본더" 주문 폭주... 역대급 실적 예고', 'url': 'https://search.naver.com/search.naver?where=news&query=한미반도체+TC본더'}
        ]
      },
    ],
    '전기차': [
      {
        'symbol': '000270', 
        'name': '기아', 
        'sector': '전기차', 
        'marketCap': 35000000000000, 
        'description': '전기차 제조',
        'reason': 'EV9 등 고수익 대형 전기차 판매 호조로 이익률 개선',
        'news': [
          {'title': '기아, "EV 데이" 개최... 보급형 전기차 라인업 공개', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+EV데이'},
          {'title': '북미·유럽서 전기차 판매 비중 20% 돌파 임박', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+전기차+판매비중'}
        ]
      },
      {
        'symbol': '005380', 
        'name': '현대차', 
        'sector': '전기차', 
        'marketCap': 32000000000000, 
        'description': '전기차 제조',
        'reason': '아이오닉 시리즈의 글로벌 호평 및 하이브리드 판매 견조',
        'news': [
          {'title': '현대차, 싱가포르 글로벌 혁신센터 준공... 전기차 제조 혁신', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+싱가포르+혁신센터'},
          {'title': '아이오닉6, 미국서 최고 안전 등급 획득', 'url': 'https://search.naver.com/search.naver?where=news&query=아이오닉6+안전등급'}
        ]
      },
      {
        'symbol': '003670', 
        'name': '포스코홀딩스', 
        'sector': '전기차', 
        'marketCap': 28000000000000, 
        'description': '자동차 소재',
        'reason': '전기차 모터코어용 전기강판 생산 능력 확대로 소재 공급 주도',
        'news': [
          {'title': '포스코, 구동모터 코어 공장 증설... 2030년 700만대 체제', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코+구동모터코어'},
          {'title': '기가스틸 등 초경량 차체 소재 수주 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코+기가스틸'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '전기차', 
        'marketCap': 18000000000000, 
        'description': '배터리 소재',
        'reason': 'LG에너지솔루션 지분 가치 및 첨단소재 사업부 고성장',
        'news': [
          {'title': 'LG화학, 배터리 소재 매출 비중 50%까지 확대 목표', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+배터리소재'},
          {'title': '탄소나노튜브(CNT) 공장 증설... 도전재 시장 공략', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+CNT'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '전기차', 
        'marketCap': 15000000000000, 
        'description': '배터리 시스템',
        'reason': 'BMW 등 글로벌 완성차 업체와의 장기 공급 계약으로 안정적 성장',
        'news': [
          {'title': '삼성SDI, 헝가리 배터리 공장 증설 추진', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+헝가리공장'},
          {'title': '볼보트럭과 전기 트럭용 배터리 팩 공급 계약 체결', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+볼보트럭'}
        ]
      },
    ],
    '수소차': [
      {
        'symbol': '000270', 
        'name': '기아', 
        'sector': '수소차', 
        'marketCap': 35000000000000, 
        'description': '수소차 제조',
        'reason': '군수용 수소차 개발 및 특수목적 차량(PBV) 수소화 추진',
        'news': [
          {'title': '기아, 차세대 군용 차량에 수소 연료전지 탑재', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+수소차+군용'},
          {'title': '수소 트럭 등 상용차 라인업 확대 계획 발표', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+수소트럭'}
        ]
      },
      {
        'symbol': '005380', 
        'name': '현대차', 
        'sector': '수소차', 
        'marketCap': 32000000000000, 
        'description': '수소차 제조',
        'reason': '넥쏘 후속 모델 개발 및 승용/상용 수소차 라인업 보유',
        'news': [
          {'title': '현대차 유니버스 수소전기버스 출시... 대중교통 친환경화', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+유니버스+수소'},
          {'title': '북미 수소 트럭 시장 진출 본격화', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+수소트럭+북미'}
        ]
      },
      {
        'symbol': '003670', 
        'name': '포스코홀딩스', 
        'sector': '수소차', 
        'marketCap': 28000000000000, 
        'description': '수소 소재',
        'reason': '그린수소 생산부터 환원제철까지 수소 생태계 전반 구축',
        'news': [
          {'title': '오만 그린수소 독점 개발권 확보... 연 22만톤 생산', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코홀딩스+오만+수소'},
          {'title': '수소환원제철 실증 플랜트 착공 임박', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코+수소환원제철'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '수소차', 
        'marketCap': 18000000000000, 
        'description': '수소 연료전지',
        'reason': '수소 연료전지 핵심 소재인 멤브레인 기술력 보유',
        'news': [
          {'title': '수전해 핵심 소재 멤브레인 국산화 성공', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+멤브레인'},
          {'title': '친환경 수소 생산 기술 개발 박차', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+수소생산'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '수소차', 
        'marketCap': 15000000000000, 
        'description': '수소 시스템',
        'reason': '연료전지 효율 향상을 위한 핵심 소재 연구 개발 진행 중',
        'news': [
          {'title': '연료전지용 전극 소재 기술 개발 협력', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+연료전지'},
          {'title': '친환경 에너지 솔루션 기업으로 도약 선언', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+친환경에너지'}
        ]
      },
    ],
    'AI': [
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': 'AI', 
        'marketCap': 45000000000000, 
        'description': 'AI 반도체',
        'reason': '온디바이스 AI 폰 출시 및 AI 가전 생태계 확장',
        'news': [
          {'title': '삼성 가우스 AI, 갤럭시 S24 탑재로 모바일 경험 혁신', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성+가우스+S24'},
          {'title': 'CES 2024서 "AI 스크린" 시대 선언', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성+CES+AI스크린'}
        ]
      },
      {
        'symbol': '000660', 
        'name': 'SK하이닉스', 
        'sector': 'AI', 
        'marketCap': 42000000000000, 
        'description': 'AI 메모리',
        'reason': 'AI 서버용 고성능 메모리 수요 폭증의 최대 수혜',
        'news': [
          {'title': '오픈AI 샘 올트먼, SK하이닉스와 AI 반도체 동맹 논의', 'url': 'https://search.naver.com/search.naver?where=news&query=샘올트먼+SK하이닉스'},
          {'title': 'HBM 시장 점유율 50% 육박... "AI 메모리 1위 굳히기"', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+HBM+점유율'}
        ]
      },
      {
        'symbol': '035420', 
        'name': 'NAVER', 
        'sector': 'AI', 
        'marketCap': 30000000000000, 
        'description': 'AI 플랫폼 및 서비스',
        'reason': '하이퍼클로바X 기반의 B2B AI 솔루션 수익화 본격화',
        'news': [
          {'title': '사우디판 네옴시티에 네이버 AI·디지털 트윈 수출', 'url': 'https://search.naver.com/search.naver?where=news&query=네이버+사우디+디지털트윈'},
          {'title': '네이버 검색에 생성형 AI "큐(CUE:)" 통합... 검색 점유율 방어', 'url': 'https://search.naver.com/search.naver?where=news&query=네이버+큐+검색'}
        ]
      },
      {
        'symbol': '035720', 
        'name': '카카오', 
        'sector': 'AI', 
        'marketCap': 25000000000000, 
        'description': 'AI 플랫폼 및 서비스',
        'reason': '카카오톡 기반의 AI 비서 서비스 및 모빌리티 AI 접목',
        'news': [
          {'title': '카카오브레인 AI 모델 "코GPT 2.0" 공개 임박', 'url': 'https://search.naver.com/search.naver?where=news&query=카카오+코GPT2.0'},
          {'title': '카카오 헬스케어, AI 기반 혈당 관리 서비스 출시', 'url': 'https://search.naver.com/search.naver?where=news&query=카카오헬스케어+AI'}
        ]
      },
    ],
    '바이오': [
      {
        'symbol': '207940', 
        'name': '삼성바이오로직스', 
        'sector': '바이오', 
        'marketCap': 42000000000000, 
        'description': '바이오 의약품',
        'reason': '글로벌 1위 CDMO(위탁개발생산) 경쟁력 및 5공장 증설 효과',
        'news': [
          {'title': '삼성바이오, 글로벌 제약사와 1조원 규모 위탁생산 계약', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오로직스+위탁생산'},
          {'title': '5공장 조기 가동 계획... 수주 물량 대응 총력', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+5공장'}
        ]
      },
      {
        'symbol': '068270', 
        'name': '셀트리온', 
        'sector': '바이오', 
        'marketCap': 35000000000000, 
        'description': '바이오 의약품',
        'reason': '짐펜트라 미국 출시 및 바이오시밀러 포트폴리오 다각화',
        'news': [
          {'title': '셀트리온 합병법인 출범... "2030년 매출 12조 목표"', 'url': 'https://search.naver.com/search.naver?where=news&query=셀트리온+합병'},
          {'title': '짐펜트라, 미국 주요 PBM 처방집 등재 성공', 'url': 'https://search.naver.com/search.naver?where=news&query=짐펜트라+PBM'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '바이오', 
        'marketCap': 18000000000000, 
        'description': '바이오 소재',
        'reason': '미국 항암 신약 시장 진출 및 아베오 인수 시너지 기대',
        'news': [
          {'title': 'LG화학 신약 파이프라인 30개로 확대... 글로벌 임상 가속', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+신약'},
          {'title': '통풍 치료제 미국 임상 3상 순항', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+통풍치료제'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '바이오', 
        'marketCap': 15000000000000, 
        'description': '바이오 시스템',
        'reason': '의료기기용 초소형 고효율 배터리 시장 점유율 확대',
        'news': [
          {'title': '디지털 헬스케어 기기용 초소형 배터리 출시', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+소형배터리'},
          {'title': '웨어러블 의료기기 시장 성장 수혜', 'url': 'https://search.naver.com/search.naver?where=news&query=웨어러블+의료기기+배터리'}
        ]
      },
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': '바이오', 
        'marketCap': 12000000000000, 
        'description': '바이오 장비',
        'reason': '삼성 메디슨을 통한 최첨단 의료기기 및 헬스케어 AI 사업',
        'news': [
          {'title': '삼성 헬스, AI 기반 수면 관리 기능 강화', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성헬스+수면'},
          {'title': '차세대 초음파 진단기기 북미 시장 공략', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성메디슨+초음파'}
        ]
      },
    ],
    '자동차부품': [
      {
        'symbol': '000270', 
        'name': '기아', 
        'sector': '자동차부품', 
        'marketCap': 35000000000000, 
        'description': '자동차 부품',
        'reason': '안정적인 글로벌 판매망과 완성차 부품 수직계열화 효율성',
        'news': [
          {'title': '기아, 글로벌 품질 평가 상위권 랭크', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+품질평가'},
          {'title': 'PBV 전용 공장 광명에 구축... 부품 생태계 확장', 'url': 'https://search.naver.com/search.naver?where=news&query=기아+PBV+공장'}
        ]
      },
      {
        'symbol': '005380', 
        'name': '현대차', 
        'sector': '자동차부품', 
        'marketCap': 32000000000000, 
        'description': '자동차 부품',
        'reason': '현대모비스 등 그룹사와의 협력으로 미래 모빌리티 부품 경쟁력 확보',
        'news': [
          {'title': '소프트웨어 중심 자동차(SDV) 전환 가속... 부품사 협력 강화', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+SDV+부품'},
          {'title': '현대차그룹, 자율주행 부품 내재화율 높인다', 'url': 'https://search.naver.com/search.naver?where=news&query=현대차+자율주행+부품'}
        ]
      },
      {
        'symbol': '003670', 
        'name': '포스코홀딩스', 
        'sector': '자동차부품', 
        'marketCap': 28000000000000, 
        'description': '자동차 소재',
        'reason': '초경량 자동차 강판 기술력으로 전기차 연비 개선 기여',
        'news': [
          {'title': '포스코 기가스틸, 글로벌 완성차 업체 채택 증가', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코+기가스틸'},
          {'title': '전기차용 하이퍼 NO 전기강판 공장 준공', 'url': 'https://search.naver.com/search.naver?where=news&query=포스코+전기강판'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '자동차부품', 
        'marketCap': 18000000000000, 
        'description': '자동차 소재',
        'reason': '차량 경량화를 위한 엔지니어링 플라스틱 소재 공급 확대',
        'news': [
          {'title': 'LG화학, 금속 대체할 고강도 플라스틱 소재 개발', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+고강도플라스틱'},
          {'title': '차량용 디스플레이 소재 시장 점유율 1위 목표', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+디스플레이소재'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '자동차부품', 
        'marketCap': 15000000000000, 
        'description': '자동차 전자',
        'reason': '차량용 디스플레이 소재 및 전자장비 부품 사업 확장',
        'news': [
          {'title': 'OLED 디스플레이 소재, 프리미엄 차량 탑재 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+OLED+차량'},
          {'title': '전장용 소재 분야 매출 매년 20% 성장', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+전장소재'}
        ]
      },
    ],
    '의료기기': [
      {
        'symbol': '207940', 
        'name': '삼성바이오로직스', 
        'sector': '의료기기', 
        'marketCap': 42000000000000, 
        'description': '의료기기',
        'reason': '바이오 프로세스 기술력을 바탕으로 한 의약품 생산 장비 고도화',
        'news': [
          {'title': '차세대 바이오 의약품 생산 공정 개발 성공', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+생산공정'},
          {'title': '친환경 제약 생산 기술 도입... ESG 경영 강화', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+ESG'}
        ]
      },
      {
        'symbol': '068270', 
        'name': '셀트리온', 
        'sector': '의료기기', 
        'marketCap': 35000000000000, 
        'description': '의료기기',
        'reason': '자가주사 제형 변경 기술(SC)로 환자 편의성 증대 의료기기 개발',
        'news': [
          {'title': '램시마SC, 유럽 시장 점유율 지속 상승', 'url': 'https://search.naver.com/search.naver?where=news&query=램시마SC+유럽'},
          {'title': '디지털 헬스케어 플랫폼 개발 통한 환자 모니터링 강화', 'url': 'https://search.naver.com/search.naver?where=news&query=셀트리온+디지털헬스케어'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '의료기기', 
        'marketCap': 18000000000000, 
        'description': '의료기기 소재',
        'reason': '미용 필러 등 에스테틱 의료기기 소재 시장의 강자',
        'news': [
          {'title': 'LG화학 필러 "이브아르", 중국 시장 판매 호조', 'url': 'https://search.naver.com/search.naver?where=news&query=이브아르+중국'},
          {'title': '재생 의료 소재 기술 개발 투자 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+재생의료'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '의료기기', 
        'marketCap': 15000000000000, 
        'description': '의료기기 시스템',
        'reason': '휴대용 의료기기 및 전동 공구용 소형 배터리 세계 1위',
        'news': [
          {'title': '고출력 원통형 배터리, 수술용 전동 공구 탑재 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+원통형+의료기기'},
          {'title': '무선 의료기기 시장 성장에 소형 전지 수요 견조', 'url': 'https://search.naver.com/search.naver?where=news&query=무선의료기기+배터리'}
        ]
      },
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': '의료기기', 
        'marketCap': 12000000000000, 
        'description': '의료기기 장비',
        'reason': 'AI 진단 보조 기능을 탑재한 프리미엄 영상 진단 기기 확대',
        'news': [
          {'title': '삼성 메디슨, 산부인과용 프리미엄 초음파 기기 출시', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성메디슨+산부인과'},
          {'title': 'AI로 유방암 진단 돕는 초음파 기술 개발', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성+AI+유방암'}
        ]
      },
    ],
    '방산주': [
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': '방산주', 
        'marketCap': 45000000000000, 
        'description': '방산 전자',
        'reason': '군사 통신 및 감시 정찰 장비에 필수적인 특수 반도체 공급',
        'news': [
          {'title': '극한 환경에서도 작동하는 특수 반도체 개발', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+특수반도체'},
          {'title': '국방과학연구소와 차세대 통신 기술 협력', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+국방과학연구소'}
        ]
      },
      {
        'symbol': '000660', 
        'name': 'SK하이닉스', 
        'sector': '방산주', 
        'marketCap': 42000000000000, 
        'description': '방산 전자',
        'reason': '국방 첨단 무기 체계 고도화에 따른 내구성 높은 메모리 수요',
        'news': [
          {'title': '국방용 내열·내충격 메모리 반도체 공급 확대', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+국방용+메모리'},
          {'title': '사이버 보안 강화된 국방용 메모리 솔루션 개발', 'url': 'https://search.naver.com/search.naver?where=news&query=국방용+메모리+보안'}
        ]
      },
      {
        'symbol': '207940', 
        'name': '삼성바이오로직스', 
        'sector': '방산주', 
        'marketCap': 38000000000000, 
        'description': '방산 시스템',
        'reason': '생물 보안법 관련 생물학적 위협 대응 백신 및 치료제 생산 거점',
        'news': [
          {'title': '미국 생물보안법 수혜 기대... 중국 CDMO 대체제 부상', 'url': 'https://search.naver.com/search.naver?where=news&query=미국+생물보안법+삼성바이오'},
          {'title': '국가 필수 백신 국산화 프로젝트 참여', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+백신+국산화'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '방산주', 
        'marketCap': 18000000000000, 
        'description': '방산 소재',
        'reason': '방탄 유리 및 고강도 복합 소재 군수용 적용 확대',
        'news': [
          {'title': '경량 방탄 헬멧용 첨단 소재 개발', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+방탄소재'},
          {'title': '군용차 타이어 및 내장재용 특수 고무 공급', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+군용차+소재'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '방산주', 
        'marketCap': 15000000000000, 
        'description': '방산 시스템',
        'reason': '군용 드론 및 잠수함용 특수 배터리 시스템 기술 보유',
        'news': [
          {'title': '장시간 체공 군용 드론을 위한 고밀도 배터리 솔루션', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+군용드론+배터리'},
          {'title': '잠수함용 리튬이온 배터리 체계 공급 이력', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+잠수함+배터리'}
        ]
      },
    ],
    '밸류업': [
      {
        'symbol': '005930', 
        'name': '삼성전자', 
        'sector': '밸류업', 
        'marketCap': 45000000000000, 
        'description': '밸류 종목',
        'reason': '풍부한 현금성 자산을 바탕으로 한 주주 환원 및 PBR 저평가 해소 기대',
        'news': [
          {'title': '삼성전자, 분기 배당 실시... 주주 친화 정책 지속', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+배당'},
          {'title': '현금 보유액 100조 육박... M&A 기대감 솔솔', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성전자+현금+M&A'}
        ]
      },
      {
        'symbol': '000660', 
        'name': 'SK하이닉스', 
        'sector': '밸류업', 
        'marketCap': 42000000000000, 
        'description': '밸류 종목',
        'reason': '실적 턴어라운드와 함께 배당 확대 등 주주 가치 제고 정책 강화',
        'news': [
          {'title': 'SK하이닉스, 실적 개선에 주주 환원율 상향 검토', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+주주환원'},
          {'title': '자사주 매입 및 소각 기대감 작용', 'url': 'https://search.naver.com/search.naver?where=news&query=SK하이닉스+자사주'}
        ]
      },
      {
        'symbol': '207940', 
        'name': '삼성바이오로직스', 
        'sector': '밸류업', 
        'marketCap': 38000000000000, 
        'description': '밸류 종목',
        'reason': '고성장에도 불구하고 안정적인 재무 구조와 투명한 지배구조',
        'news': [
          {'title': '영업이익 1조 클럽 가입... 성장과 수익성 동시 달성', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+영업이익+1조'},
          {'title': 'ESG 평가 최우수 등급 획득... 지속가능경영 인정', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성바이오+ESG'}
        ]
      },
      {
        'symbol': '051910', 
        'name': 'LG화학', 
        'sector': '밸류업', 
        'marketCap': 18000000000000, 
        'description': '밸류 종목',
        'reason': '친환경 소재 및 전지 소재 중심의 사업 재편으로 기업 가치 재평가',
        'news': [
          {'title': '3대 신성장 동력에 10조 투자... 사업 포트폴리오 대전환', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+신성장투자'},
          {'title': '석유화학 불황에도 배터리 소재가 실적 방어', 'url': 'https://search.naver.com/search.naver?where=news&query=LG화학+실적+배터리'}
        ]
      },
      {
        'symbol': '006400', 
        'name': '삼성SDI', 
        'sector': '밸류업', 
        'marketCap': 15000000000000, 
        'description': '밸류 종목',
        'reason': '보수적인 투자 기조에서 벗어난 적극적 주주 환원 및 성장 투자 조화',
        'news': [
          {'title': '삼성SDI, 3년 연속 사상 최대 매출 경신 도전', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+최대매출'},
          {'title': '수익성 위주의 질적 성장 전략 유효... 프리미엄 배터리 집중', 'url': 'https://search.naver.com/search.naver?where=news&query=삼성SDI+질적성장'}
        ]
      },
    ],
  };

  // 테마 목록 가져오기
  static List<String> getThemes() {
    return _themeStocks.keys.toList();
  }

  // 특정 테마의 추천 종목 가져오기
  static List<Map<String, dynamic>> getThemeStocks(String theme) {
    return _themeStocks[theme] ?? [];
  }
}