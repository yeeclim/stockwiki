class UsSectorLoader {
  static const Map<String, List<Map<String, dynamic>>> _sectorStocks = {
    'Technology': [
      {
        'symbol': 'NVDA',
        'name': 'NVIDIA',
        'sector': 'Technology',
        'description': 'AI Computing & GPU',
        'reason': 'AI 데이터 센터 GPU 시장을 장악하고 있으며 CUDA 생태계로 강력한 진입 장벽을 구축함.',
        'news': [
          {'title': 'NVIDIA Blackwell GPU demand outstrips supply', 'url': 'https://www.google.com/search?q=NVIDIA+Blackwell+GPU+news&tbm=nws'},
          {'title': 'AI revolution drives record data center revenue', 'url': 'https://www.google.com/search?q=NVIDIA+data+center+revenue+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'MSFT',
        'name': 'Microsoft',
        'sector': 'Technology',
        'description': 'Cloud & Productivity',
        'reason': 'OpenAI 파트너십과 Copilot을 통해 생성형 AI 통합을 선도하며 클라우드 성장 가속화.',
        'news': [
          {'title': 'Microsoft Copilot adoption rates in enterprise soar', 'url': 'https://www.google.com/search?q=Microsoft+Copilot+adoption+news&tbm=nws'},
          {'title': 'Azure cloud growth accelerates due to AI demand', 'url': 'https://www.google.com/search?q=Microsoft+Azure+growth+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'AAPL',
        'name': 'Apple',
        'sector': 'Technology',
        'description': 'Consumer Electronics',
        'reason': '강력한 생태계 유지율과 AI 기능(Apple Intelligence)이 탑재된 아이폰의 슈퍼 사이클 기대.',
        'news': [
          {'title': 'Apple Intelligence features rolling out to new devices', 'url': 'https://www.google.com/search?q=Apple+Intelligence+features+news&tbm=nws'},
          {'title': 'Services revenue reaches all-time high', 'url': 'https://www.google.com/search?q=Apple+services+revenue+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'AVGO',
        'name': 'Broadcom',
        'sector': 'Technology',
        'description': 'Semiconductors & Software',
        'reason': '맞춤형 AI 칩(ASIC) 및 네트워크 인프라의 핵심 공급업체로, VMware 통합 시너지 기대.',
        'news': [
          {'title': 'Broadcom AI chip sales forecast raised', 'url': 'https://www.google.com/search?q=Broadcom+AI+chip+sales+news&tbm=nws'},
          {'title': 'VMware integration driving software segment growth', 'url': 'https://www.google.com/search?q=Broadcom+VMware+integration+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'AMD',
        'name': 'AMD',
        'sector': 'Technology',
        'description': 'Semiconductors',
        'reason': '데이터 센터 CPU/GPU 시장에서 시장 리더의 강력한 대안으로 경쟁력 확보.',
        'news': [
          {'title': 'AMD instict MI300 series challenges NVIDIA dominance', 'url': 'https://www.google.com/search?q=AMD+MI300+news&tbm=nws'},
          {'title': 'Server market share gains continue against Intel', 'url': 'https://www.google.com/search?q=AMD+server+market+share+news&tbm=nws'}
        ]
      },
    ],
    'Healthcare': [
      {
        'symbol': 'LLY',
        'name': 'Eli Lilly',
        'sector': 'Healthcare',
        'description': 'Pharmaceuticals',
        'reason': 'GLP-1 비만 치료제(Zepbound) 시장의 리더이자 알츠하이머 치료제 파이프라인 보유.',
        'news': [
          {'title': 'Zepbound sales surpass expectations in US market', 'url': 'https://www.google.com/search?q=Eli+Lilly+Zepbound+sales+news&tbm=nws'},
          {'title': 'Positive trial results for new Alzheimer drug', 'url': 'https://www.google.com/search?q=Eli+Lilly+Alzheimer+drug+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'NVO',
        'name': 'Novo Nordisk',
        'sector': 'Healthcare',
        'description': 'Pharmaceuticals',
        'reason': '위고비(Wegovy)와 오젬픽(Ozempic)으로 비만 치료 시장을 개척하며 강력한 장기 수요 확보.',
        'news': [
          {'title': 'Wegovy cardiovascular benefits confirmed in study', 'url': 'https://www.google.com/search?q=Novo+Nordisk+Wegovy+news&tbm=nws'},
          {'title': 'Boosting production capacity to meet global demand', 'url': 'https://www.google.com/search?q=Novo+Nordisk+production+capacity+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'UNH',
        'name': 'UnitedHealth',
        'sector': 'Healthcare',
        'description': 'Managed Health Care',
        'reason': 'Optum을 통한 사업 다각화로 안정적인 현금 흐름과 의료 서비스 시장 지배력 보유.',
        'news': [
          {'title': 'UnitedHealth reports solid earnings despite cyberattack impact', 'url': 'https://www.google.com/search?q=UnitedHealth+earnings+news&tbm=nws'},
          {'title': 'Optum Health expends care delivery capabilities', 'url': 'https://www.google.com/search?q=UnitedHealth+Optum+expansion+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'JNJ',
        'name': 'Johnson & Johnson',
        'sector': 'Healthcare',
        'description': 'Pharmaceuticals & MedTech',
        'reason': '소비자 건강 부문 분사 후 고성장 제약 및 의료기기(MedTech) 분야에 집중.',
        'news': [
          {'title': 'MedTech aquisition expands cardiovascular portfolio', 'url': 'https://www.google.com/search?q=JNJ+MedTech+acquisition+news&tbm=nws'},
          {'title': 'Strong immunology drug sales drive growth', 'url': 'https://www.google.com/search?q=JNJ+immunology+sales+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'MRK',
        'name': 'Merck',
        'sector': 'Healthcare',
        'description': 'Pharmaceuticals',
        'reason': '키트루다(Keytruda)가 항암제 시장을 지배하며 적응증 확대로 지속 성장 중.',
        'news': [
          {'title': 'Keytruda sales hit new record high', 'url': 'https://www.google.com/search?q=Merck+Keytruda+sales+news&tbm=nws'},
          {'title': 'FDA approves new indication for cancer therapy', 'url': 'https://www.google.com/search?q=Merck+FDA+approval+news&tbm=nws'}
        ]
      },
    ],
    'Finance': [
      {
        'symbol': 'JPM',
        'name': 'JPMorgan Chase',
        'sector': 'Finance',
        'description': 'Diversified Banking',
        'reason': '미국 내 가장 강력한 대차대조표와 업계 최고의 자기자본이익률(ROE)을 자랑하는 은행.',
        'news': [
          {'title': 'JPMorgan net interest income beats estimates', 'url': 'https://www.google.com/search?q=JPMorgan+earnings+news&tbm=nws'},
          {'title': 'Jamie Dimon comments on US economic resilience', 'url': 'https://www.google.com/search?q=Jamie+Dimon+economic+outlook+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'V',
        'name': 'Visa',
        'sector': 'Finance',
        'description': 'Payment Services',
        'reason': '디지털 결제로의 글로벌 전환과 높은 마진율로 인플레이션 방어주 역할.',
        'news': [
          {'title': 'Cross-border payment volume surges post-pandemic', 'url': 'https://www.google.com/search?q=Visa+cross-border+volume+news&tbm=nws'},
          {'title': 'Visa introduces new anti-fraud AI technology', 'url': 'https://www.google.com/search?q=Visa+AI+fraud+detection+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'MA',
        'name': 'Mastercard',
        'sector': 'Finance',
        'description': 'Payment Services',
        'reason': '고성장 신흥 시장에 대한 노출도가 높고 부가 서비스 확장을 통해 성장 중.',
        'news': [
          {'title': 'Mastercard expands crypto payment network', 'url': 'https://www.google.com/search?q=Mastercard+crypto+news&tbm=nws'},
          {'title': 'Strong demand for travel boosts transaction volumes', 'url': 'https://www.google.com/search?q=Mastercard+travel+volume+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'BAC',
        'name': 'Bank of America',
        'sector': 'Finance',
        'description': 'Diversified Banking',
        'reason': '막대한 소비자 예금 기반으로 고금리 환경의 수혜를 입음.',
        'news': [
          {'title': 'Bank of America digital user base crosses 57 million', 'url': 'https://www.google.com/search?q=Bank+of+America+digital+users+news&tbm=nws'},
          {'title': 'Trading revenue jumps in volatile market', 'url': 'https://www.google.com/search?q=Bank+of+America+trading+revenue+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'BLK',
        'name': 'BlackRock',
        'sector': 'Finance',
        'description': 'Asset Management',
        'reason': 'ETF(iShares) 자금 유입 1위 및 인프라 투자 확대로 자산 운용 시장 지배.',
        'news': [
          {'title': 'Bitcoin ETF inflows shatter records', 'url': 'https://www.google.com/search?q=BlackRock+Bitcoin+ETF+news&tbm=nws'},
          {'title': 'Aquisition of GIP to boost infrastructure business', 'url': 'https://www.google.com/search?q=BlackRock+GIP+acquisition+news&tbm=nws'}
        ]
      },
    ],
    'Consumer': [
      {
        'symbol': 'AMZN',
        'name': 'Amazon',
        'sector': 'Consumer',
        'description': 'E-commerce & Cloud',
        'reason': '물류 효율화를 통한 소매 마진 개선과 AWS의 AI 가속기 성장이 동시 진행 중.',
        'news': [
          {'title': 'Prime Day sales set new global record', 'url': 'https://www.google.com/search?q=Amazon+Prime+Day+sales+news&tbm=nws'},
          {'title': 'AWS introduces new generative AI chips', 'url': 'https://www.google.com/search?q=Amazon+AWS+AI+chips+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'COST',
        'name': 'Costco',
        'sector': 'Consumer',
        'description': 'Retail',
        'reason': '압도적인 멤버십 충성도와 가격 경쟁력으로 인플레이션 시기에 더욱 돋보이는 기업.',
        'news': [
          {'title': 'Costco membership fee increase likely to boost earnings', 'url': 'https://www.google.com/search?q=Costco+membership+fee+news&tbm=nws'},
          {'title': 'Gold bars selling out instantly at Costco online', 'url': 'https://www.google.com/search?q=Costco+gold+bars+sales+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'WMT',
        'name': 'Walmart',
        'sector': 'Consumer',
        'description': 'Retail',
        'reason': '고소득층 소비자의 유입 및 광고 사업 성장으로 수익성 개선.',
        'news': [
          {'title': 'Walmart+ membership growth exceeds targets', 'url': 'https://www.google.com/search?q=Walmart+plus+growth+news&tbm=nws'},
          {'title': 'Automation in supply chain improves margins', 'url': 'https://www.google.com/search?q=Walmart+automation+supply+chain+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'KO',
        'name': 'Coca-Cola',
        'sector': 'Consumer',
        'description': 'Beverages',
        'reason': '강력한 가격 결정력과 글로벌 유통망을 갖춘 최고의 필수소비재 방어주.',
        'news': [
          {'title': 'Organic revenue grows despite price hikes', 'url': 'https://www.google.com/search?q=Coca-Cola+revenue+growth+news&tbm=nws'},
          {'title': 'Warren Buffett reaffirms long-term holding', 'url': 'https://www.google.com/search?q=Warren+Buffett+Coca-Cola+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'PG',
        'name': 'Procter & Gamble',
        'sector': 'Consumer',
        'description': 'Household Products',
        'reason': '필수 생활용품 브랜드 포트폴리오를 보유한 신뢰할 수 있는 배당 성장주.',
        'news': [
          {'title': 'P&G raises full-year earnings guidance', 'url': 'https://www.google.com/search?q=Procter&Gamble+earnings+guidance+news&tbm=nws'},
          {'title': 'Innovative product launches drive volume growth', 'url': 'https://www.google.com/search?q=P&G+new+products+news&tbm=nws'}
        ]
      },
    ],
    'Energy': [
      {
        'symbol': 'XOM',
        'name': 'Exxon Mobil',
        'sector': 'Energy',
        'description': 'Integrated Oil & Gas',
        'reason': '업계 최고의 상류(Upstream) 포트폴리오(가이아나, 퍼미안)와 탄탄한 재무구조 보유.',
        'news': [
          {'title': 'Exxon Mobil acquires Pioneer Natural Resources', 'url': 'https://www.google.com/search?q=Exxon+Pioneer+acquisition+news&tbm=nws'},
          {'title': 'Guyana offshore production reaches new milestone', 'url': 'https://www.google.com/search?q=Exxon+Guyana+production+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'CVX',
        'name': 'Chevron',
        'sector': 'Energy',
        'description': 'Integrated Oil & Gas',
        'reason': '일관된 주주 환원 정책(배당/자사주 매입)과 효율적인 운영 능력.',
        'news': [
          {'title': 'Chevron announces Hess Corp acquisition', 'url': 'https://www.google.com/search?q=Chevron+Hess+acquisition+news&tbm=nws'},
          {'title': 'Commitment to lower carbon energy investments', 'url': 'https://www.google.com/search?q=Chevron+low+carbon+strategy+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'NEE',
        'name': 'NextEra Energy',
        'sector': 'Energy',
        'description': 'Utilities & Renewable',
        'reason': '세계 최대의 재생 에너지 개발사이자 안정적인 유틸리티 사업을 영위.',
        'news': [
          {'title': 'Renewable energy backlog hits record highs', 'url': 'https://www.google.com/search?q=NextEra+Energy+renewables+news&tbm=nws'},
          {'title': 'Florida Power & Light plans solar expansion', 'url': 'https://www.google.com/search?q=FPL+solar+expansion+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'COP',
        'name': 'ConocoPhillips',
        'sector': 'Energy',
        'description': 'E&P',
        'reason': '낮은 공급 비용에 집중하는 E&P(탐사 및 생산) 기업으로 강력한 현금 흐름 창출.',
        'news': [
          {'title': 'Willow project in Alaska receives final approval', 'url': 'https://www.google.com/search?q=ConocoPhillips+Willow+project+news&tbm=nws'},
          {'title': 'Special dividend declared amidst strong cash flow', 'url': 'https://www.google.com/search?q=ConocoPhillips+dividend+news&tbm=nws'}
        ]
      },
      {
        'symbol': 'SLB',
        'name': 'Schlumberger',
        'sector': 'Energy',
        'description': 'Oilfield Services',
        'reason': '글로벌 해양 시추 부활과 에너지 산업의 디지털 솔루션 도입 수혜.',
        'news': [
          {'title': 'International revenue drives earnings beat', 'url': 'https://www.google.com/search?q=Schlumberger+earnings+news&tbm=nws'},
          {'title': 'Partnership with AWS to digitize energy industry', 'url': 'https://www.google.com/search?q=Schlumberger+AWS+partnership+news&tbm=nws'}
        ]
      },
    ],
  };

  static List<String> getSectors() {
    return _sectorStocks.keys.toList();
  }

  static List<Map<String, dynamic>> getSectorStocks(String sector) {
    return _sectorStocks[sector] ?? [];
  }
}
