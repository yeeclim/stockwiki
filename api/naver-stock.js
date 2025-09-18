export default async function handler(req, res) {
  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  try {
    // 네이버 금융에서 직접 스크래핑
    const stockData = await fetchFromNaver(symbol);
    
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'naver-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 네이버 실패시 Yahoo Finance 시도
    const yahooData = await fetchFromYahoo(symbol);
    if (yahooData) {
      return res.status(200).json({
        success: true,
        data: yahooData,
        source: 'yahoo-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 모든 API 실패시 더미 데이터 반환
    const dummyData = generateDummyData(symbol);
    if (dummyData) {
      return res.status(200).json({
        success: true,
        data: dummyData,
        source: 'dummy-data',
        note: '실시간 API 실패로 더미 데이터 사용',
        timestamp: new Date().toISOString()
      });
    }

    return res.status(404).json({
      success: false,
      error: '해당 종목 데이터를 찾을 수 없습니다'
    });

  } catch (error) {
    console.error('주식 데이터 가져오기 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function fetchFromNaver(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.nhn?code=${symbol}`;
    
    console.log(`네이버 금융 스크래핑: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      }
    });

    if (!response.ok) {
      console.log(`네이버 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 네이버 금융 페이지에서 주가 정보 추출
    const priceMatch = html.match(/<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    const changeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d,]+)<\/span>/);
    const changePercentMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d.]+)%<\/span>/);
    const volumeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([\d,]+)<\/span>/);
    
    // 더 정확한 정규식으로 재시도
    const priceMatch2 = html.match(/"no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    const changeMatch2 = html.match(/<span[^>]*class="[^"]*tah[^"]*"[^>]*>([+-]?[\d,]+)<\/span>/);
    
    if (!priceMatch && !priceMatch2) {
      console.log('네이버에서 가격 정보를 찾을 수 없습니다');
      return null;
    }

    const priceText = (priceMatch ? priceMatch[1] : priceMatch2[1]).replace(/,/g, '');
    const price = parseFloat(priceText);
    
    if (isNaN(price)) {
      console.log('가격 파싱 실패:', priceText);
      return null;
    }

    // 등락 정보 추출 (더 간단한 방법)
    const changeText = changeMatch ? changeMatch[1].replace(/,/g, '') : '0';
    const change = parseFloat(changeText) || 0;
    
    const changePercentText = changePercentMatch ? changePercentMatch[1].replace('%', '') : '0';
    const changePercent = parseFloat(changePercentText) || 0;
    
    const volumeText = volumeMatch ? volumeMatch[1].replace(/,/g, '') : '0';
    const volume = parseInt(volumeText) || 0;

    const stockData = {
      symbol: symbol,
      name: getStockName(symbol),
      price: price,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: 0, // 네이버에서는 시가총액 정보가 제한적
      lastUpdate: new Date().toISOString()
    };

    console.log('네이버 스크래핑 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('네이버 스크래핑 오류:', error);
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
      lastUpdate: new Date().toISOString()
    };

  } catch (error) {
    console.error('Yahoo Finance 오류:', error);
    return null;
  }
}

function getStockName(symbol) {
  const names = {
    '005930': '삼성전자',
    '000660': 'SK하이닉스',
    '035420': 'NAVER',
    '035720': '카카오',
    '096350': '대창솔루션',
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
    '096350': {'price': 476, 'change': 10, 'volume': 2000000, 'marketCap': 5000000000000}, // 실제 가격으로 업데이트
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
    lastUpdate: new Date().toISOString()
  };
}
