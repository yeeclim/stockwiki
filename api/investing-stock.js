const { JSDOM } = require('jsdom');

export default async function handler(req, res) {
  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  try {
    // Investing.com에서 한국 주식 데이터 가져오기
    const stockData = await fetchStockFromInvesting(symbol);
    
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'investing.com',
        timestamp: new Date().toISO8601String()
      });
    } else {
      // Investing.com 실패시 Yahoo Finance 시도
      const yahooData = await fetchStockFromYahoo(symbol);
      if (yahooData) {
        return res.status(200).json({
          success: true,
          data: yahooData,
          source: 'yahoo-finance',
          timestamp: new Date().toISO8601String()
        });
      }
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

async function fetchStockFromInvesting(symbol) {
  try {
    // Investing.com 한국 주식 페이지 URL
    const url = `https://www.investing.com/equities/${getInvestingSymbol(symbol)}`;
    
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
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const html = await response.text();
    const dom = new JSDOM(html);
    const document = dom.window.document;

    // 가격 정보 추출
    const priceElement = document.querySelector('[data-test="instrument-price-last"]');
    const changeElement = document.querySelector('[data-test="instrument-price-change"]');
    const changePercentElement = document.querySelector('[data-test="instrument-price-change-percent"]');
    const volumeElement = document.querySelector('[data-test="instrument-volume"]');
    const nameElement = document.querySelector('h1');

    if (!priceElement) {
      return null;
    }

    const price = parseFloat(priceElement.textContent.replace(/[^\d.-]/g, ''));
    const change = changeElement ? parseFloat(changeElement.textContent.replace(/[^\d.-]/g, '')) : 0;
    const changePercent = changePercentElement ? parseFloat(changePercentElement.textContent.replace(/[^\d.-]/g, '')) : 0;
    const volume = volumeElement ? parseInt(volumeElement.textContent.replace(/[^\d]/g, '')) : 0;
    const name = nameElement ? nameElement.textContent.trim() : symbol;

    return {
      symbol: symbol,
      name: name,
      price: price,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: 0, // Investing.com에서 시가총액 정보가 제한적
      lastUpdate: new Date().toISO8601String()
    };

  } catch (error) {
    console.error('Investing.com 데이터 가져오기 실패:', error);
    return null;
  }
}

async function fetchStockFromYahoo(symbol) {
  try {
    // Yahoo Finance API 사용
    const yahooSymbol = `${symbol}.KS`; // 한국 주식은 .KS 접미사
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}`;
    
    const response = await fetch(url);
    const data = await response.json();

    if (!data.chart || !data.chart.result || data.chart.result.length === 0) {
      return null;
    }

    const result = data.chart.result[0];
    const meta = result.meta;
    const quote = result.indicators.quote[0];

    const currentPrice = meta.regularMarketPrice;
    const previousClose = meta.previousClose;
    const change = currentPrice - previousClose;
    const changePercent = (change / previousClose) * 100;
    const volume = meta.regularMarketVolume || 0;
    const marketCap = meta.marketCap || 0;

    return {
      symbol: symbol,
      name: meta.longName || symbol,
      price: currentPrice,
      change: change,
      changePercent: changePercent,
      volume: volume,
      marketCap: marketCap,
      lastUpdate: new Date().toISO8601String()
    };

  } catch (error) {
    console.error('Yahoo Finance 데이터 가져오기 실패:', error);
    return null;
  }
}

function getInvestingSymbol(symbol) {
  // 한국 주식 코드를 Investing.com 형식으로 변환
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
