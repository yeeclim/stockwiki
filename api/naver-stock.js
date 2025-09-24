export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  try {
    // 1. 네이버 스크래핑 우선 시도 (한국 주식에 더 적합)
    console.log('네이버 스크래핑 시도...');
    const stockData = await fetchFromNaver(symbol);
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'naver-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 2. 네이버 실패시 Yahoo Finance 시도 (백업용)
    console.log('네이버 실패, Yahoo Finance API 시도...');
    const yahooData = await fetchFromYahoo(symbol);
    if (yahooData) {
      return res.status(200).json({
        success: true,
        data: yahooData,
        source: 'yahoo-finance',
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
    // 간단한 정규식 기반 스크래핑 (JSDOM 없이)
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    console.log(`네이버 금융 스크래핑: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      }
    });

    if (!response.ok) {
      console.log(`네이버 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 정규식으로 가격 정보 추출
    const priceMatch = html.match(/<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    const changeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d,]+)<\/span>/);
    const changePercentMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d.]+)%<\/span>/);
    const volumeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([\d,]+)<\/span>/);
    const nameMatch = html.match(/<h2 class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    
    if (!priceMatch) {
      console.log('네이버에서 가격 정보를 찾을 수 없습니다');
      return null;
    }

    const price = parseInt(priceMatch[1].replace(/,/g, ''));
    const changeText = changeMatch ? changeMatch[1].replace(/,/g, '') : '0';
    const change = parseInt(changeText) || 0;
    const changePercentText = changePercentMatch ? changePercentMatch[1].replace('%', '') : '0';
    const changePercent = parseFloat(changePercentText) || 0;
    const volumeText = volumeMatch ? volumeMatch[1].replace(/,/g, '') : '0';
    const volume = parseInt(volumeText) || 0;
    const name = nameMatch ? nameMatch[1].trim() : getStockName(symbol);

    if (isNaN(price)) {
      console.log('가격 파싱 실패:', priceMatch[1]);
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: name,
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
