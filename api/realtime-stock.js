export default async function handler(req, res) {
  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  console.log(`실시간 주식 데이터 요청: ${symbol}`);

  try {
    // 1. Investing.com 시도
    console.log('Investing.com API 시도...');
    let stockData = await fetchFromInvesting(symbol);
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'investing.com',
        timestamp: new Date().toISO8601String()
      });
    }

    // 2. Yahoo Finance 시도
    console.log('Yahoo Finance API 시도...');
    stockData = await fetchFromYahoo(symbol);
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'yahoo-finance',
        timestamp: new Date().toISO8601String()
      });
    }

    // 3. Alpha Vantage 시도
    console.log('Alpha Vantage API 시도...');
    stockData = await fetchFromAlphaVantage(symbol);
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'alpha-vantage',
        timestamp: new Date().toISO8601String()
      });
    }

    // 4. 모든 API 실패시 더미 데이터 반환
    console.log('모든 API 실패, 더미 데이터 사용...');
    stockData = generateDummyData(symbol);
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'dummy-data',
        note: '실시간 API 실패로 더미 데이터 사용',
        timestamp: new Date().toISO8601String()
      });
    }

    return res.status(404).json({
      success: false,
      error: '해당 종목 데이터를 찾을 수 없습니다'
    });

  } catch (error) {
    console.error('실시간 주식 데이터 가져오기 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function fetchFromInvesting(symbol) {
  try {
    const url = `https://www.investing.com/equities/${getInvestingSymbol(symbol)}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
      }
    });

    if (!response.ok) return null;

    const html = await response.text();
    
    // 간단한 정규식으로 가격 정보 추출
    const priceMatch = html.match(/"last_last":"([^"]+)"/);
    const changeMatch = html.match(/"change":"([^"]+)"/);
    const changePercentMatch = html.match(/"change_percent":"([^"]+)"/);
    const volumeMatch = html.match(/"volume":"([^"]+)"/);

    if (!priceMatch) return null;

    const price = parseFloat(priceMatch[1].replace(/,/g, ''));
    const change = changeMatch ? parseFloat(changeMatch[1].replace(/,/g, '')) : 0;
    const changePercent = changePercentMatch ? parseFloat(changePercentMatch[1].replace(/[%,]/g, '')) : 0;
    const volume = volumeMatch ? parseInt(volumeMatch[1].replace(/,/g, '')) : 0;

    return {
      symbol: symbol,
      name: getStockName(symbol),
      price: price,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: 0,
      lastUpdate: new Date().toISO8601String()
    };

  } catch (error) {
    console.error('Investing.com 오류:', error);
    return null;
  }
}

async function fetchFromYahoo(symbol) {
  try {
    const yahooSymbol = `${symbol}.KS`;
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}`;
    
    const response = await fetch(url);
    const data = await response.json();

    if (!data.chart || !data.chart.result || data.chart.result.length === 0) {
      return null;
    }

    const result = data.chart.result[0];
    const meta = result.meta;

    const currentPrice = meta.regularMarketPrice;
    const previousClose = meta.previousClose;
    const change = currentPrice - previousClose;
    const changePercent = (change / previousClose) * 100;
    const volume = meta.regularMarketVolume || 0;
    const marketCap = meta.marketCap || 0;

    return {
      symbol: symbol,
      name: meta.longName || getStockName(symbol),
      price: currentPrice,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: marketCap,
      lastUpdate: new Date().toISO8601String()
    };

  } catch (error) {
    console.error('Yahoo Finance 오류:', error);
    return null;
  }
}

async function fetchFromAlphaVantage(symbol) {
  try {
    const API_KEY = 'demo'; // 실제 사용시 유료 키 필요
    const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${symbol}.KS&apikey=${API_KEY}`;
    
    const response = await fetch(url);
    const data = await response.json();

    if (data['Error Message'] || data['Note']) {
      return null;
    }

    const quote = data['Global Quote'];
    if (!quote || !quote['05. price']) {
      return null;
    }

    const price = parseFloat(quote['05. price']);
    const change = parseFloat(quote['09. change']);
    const changePercent = parseFloat(quote['10. change percent'].replace('%', ''));
    const volume = parseInt(quote['06. volume']);

    return {
      symbol: symbol,
      name: getStockName(symbol),
      price: price,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: 0,
      lastUpdate: new Date().toISO8601String()
    };

  } catch (error) {
    console.error('Alpha Vantage 오류:', error);
    return null;
  }
}

function getInvestingSymbol(symbol) {
  const symbolMap = {
    '005930': 'samsung-electronics-co-ltd',
    '000660': 'sk-hynix-inc',
    '035420': 'naver-corp',
    '035720': 'kakao-corp',
    '131390': 'daechang-solution-co-ltd',
    '207940': 'samsung-biologics-co-ltd',
    '006400': 'samsung-sdi-co-ltd',
    '051910': 'lg-chem-ltd',
    '068270': 'celltrion-inc',
    '323410': 'kakao-bank-corp',
    '000270': 'kia-corp',
    '086520': 'ecopro-co-ltd',
    '247540': 'ecopro-bm-co-ltd',
    '196170': 'alteogen-inc',
    '066970': 'lnf-co-ltd',
    '091990': 'celltrion-healthcare-co-ltd',
    '196300': 'hlb-inc',
    '196490': 'dynamic-design-inc',
    '196700': 'webzen-inc',
    '196800': 'iae-co-ltd'
  };
  
  return symbolMap[symbol] || `stock-${symbol}`;
}

function getStockName(symbol) {
  const names = {
    '005930': '삼성전자',
    '000660': 'SK하이닉스',
    '035420': 'NAVER',
    '035720': '카카오',
    '131390': '대창솔루션',
    '207940': '삼성바이오로직스',
    '006400': '삼성SDI',
    '051910': 'LG화학',
    '068270': '셀트리온',
    '323410': '카카오뱅크',
    '000270': '기아',
    '086520': '에코프로',
    '247540': '에코프로비엠',
    '196170': '알테오젠',
    '066970': '엘앤에프',
    '091990': '셀트리온헬스케어',
    '196300': '에이치엘비',
    '196490': '다이나믹디자인',
    '196700': '웹젠',
    '196800': '아이에이'
  };
  return names[symbol] || symbol;
}

function generateDummyData(symbol) {
  const dummyPrices = {
    '005930': {'price': 75000, 'change': 1500, 'volume': 12000000, 'marketCap': 450000000000000},
    '000660': {'price': 45000, 'change': -800, 'volume': 8000000, 'marketCap': 32000000000000},
    '035420': {'price': 180000, 'change': 2000, 'volume': 5000000, 'marketCap': 30000000000000},
    '035720': {'price': 420000, 'change': 5000, 'volume': 3000000, 'marketCap': 20000000000000},
    '131390': {'price': 25000, 'change': 500, 'volume': 2000000, 'marketCap': 5000000000000},
    '207940': {'price': 280000, 'change': -3000, 'volume': 4000000, 'marketCap': 35000000000000},
    '006400': {'price': 380000, 'change': 8000, 'volume': 2000000, 'marketCap': 28000000000000},
    '051910': {'price': 420000, 'change': -5000, 'volume': 1500000, 'marketCap': 30000000000000},
    '068270': {'price': 180000, 'change': 3000, 'volume': 1000000, 'marketCap': 12000000000000},
    '323410': {'price': 45000, 'change': 1000, 'volume': 5000000, 'marketCap': 20000000000000},
    '000270': {'price': 120000, 'change': -2000, 'volume': 3000000, 'marketCap': 50000000000000},
    '086520': {'price': 180000, 'change': 5000, 'volume': 800000, 'marketCap': 15000000000000},
    '247540': {'price': 220000, 'change': 8000, 'volume': 600000, 'marketCap': 18000000000000},
    '196170': {'price': 45000, 'change': -1000, 'volume': 1200000, 'marketCap': 8000000000000},
    '066970': {'price': 320000, 'change': 10000, 'volume': 400000, 'marketCap': 25000000000000},
    '091990': {'price': 85000, 'change': 2000, 'volume': 800000, 'marketCap': 12000000000000},
    '196300': {'price': 65000, 'change': -1500, 'volume': 600000, 'marketCap': 9000000000000},
    '196490': {'price': 28000, 'change': 800, 'volume': 1500000, 'marketCap': 4000000000000},
    '196700': {'price': 15000, 'change': -300, 'volume': 2000000, 'marketCap': 3000000000000},
    '196800': {'price': 35000, 'change': 1200, 'volume': 1000000, 'marketCap': 6000000000000}
  };

  const data = dummyPrices[symbol];
  if (!data) return null;

  const price = data.price;
  const change = data.change;
  const changePercent = (change / (price - change)) * 100;

  return {
    symbol: symbol,
    name: getStockName(symbol),
    price: price,
    change: change,
    changePercent: changePercent,
    volume: data.volume,
    marketCap: data.marketCap,
    lastUpdate: new Date().toISO8601String()
  };
}
