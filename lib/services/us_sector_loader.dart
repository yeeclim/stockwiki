class UsSectorLoader {
  static const Map<String, List<Map<String, dynamic>>> _sectorStocks = {
    'Technology': [
      {
        'symbol': 'NVDA',
        'name': 'NVIDIA',
        'sector': 'Technology',
        'description': 'AI Computing & GPU',
        'reason': 'Dominant market share in AI data center GPUs and CUDA ecosystem lock-in.',
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
        'reason': 'Leader in Generative AI integration specifically via OpenAI partnership and Copilot.',
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
        'reason': 'Strong ecosystem retention and potential "super cycle" with AI-enabled iPhones.',
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
        'reason': 'Critical supplier for custom AI chips (ASICs) and networking infrastructure.',
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
        'reason': 'Key competitor in data center CPU/GPU market offering valid alternatives to market leaders.',
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
        'reason': 'Market leader in GLP-1 weight loss drugs (Zepbound) and Alzheimer treatment pipeline.',
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
        'reason': 'Pioneer in obesity care with Wegovy and Ozempic showing strong long-term demand.',
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
        'reason': 'Diversified business model with Optum consistently delivering stable cash flows.',
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
        'reason': 'Refocused on high-growth Pharma and MedTech sectors after consumer health spinoff.',
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
        'reason': 'Keytruda continues to dominate oncology market with expanded indications.',
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
        'reason': 'Strongest balance sheet among big banks with best-in-class return on equity.',
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
        'reason': 'Global shift to digital payments and high margins make it a resilient compounder.',
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
        'reason': 'Exposure to high-growth emerging markets and value-added services expansion.',
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
        'reason': 'Beneficiary of "higher for longer" rates with massive consumer deposit base.',
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
        'reason': 'Leader in ETF flows (iShares) and private markets infrastructure expansion.',
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
        'reason': 'Retail margin expansion through logistics efficiency and AWS AI acceleration.',
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
        'reason': 'Unmatched membership loyalty and value proposition in inflationary environment.',
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
        'reason': 'Gaining market share from higher-income shoppers and growing advertising business.',
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
        'reason': 'Pricing power and global distribution make it a top defensive pick.',
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
        'reason': 'Reliable dividend king with portfolio of essential daily-use brands.',
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
        'reason': 'Best-in-classupstream portfolio (Guyana, Permian) and strong balance sheet.',
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
        'reason': 'Consistent capital returns (dividends/buybacks) and efficient operations.',
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
        'reason': 'Largest renewable energy developer globally with regulated utility stability.',
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
        'reason': 'Pure-play E&P focused on low cost of supply and massive cash returns.',
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
        'reason': 'Beneficiary of international offshore drilling resurgence and digital solutions.',
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
