import fetch from 'node-fetch';

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
    console.log(`종목 ${symbol} 크롤링 시작...`);
    
    // 네이버 증권에서 데이터 크롤링
    const stockData = await fetchStockData(symbol);
    
    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'naver-finance',
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

async function fetchStockData(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    console.log(`네이버 증권 크롤링: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
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
    console.log(`HTML 길이: ${html.length}`);
    
    // 종목명 추출
    const name = extractStockName(html, symbol);
    
    // 가격 정보 추출
    const priceInfo = extractPriceInfo(html);
    
    if (!priceInfo.price) {
      console.log('가격 정보를 찾을 수 없습니다');
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: name,
      price: priceInfo.price,
      change: 0, // 변동가 제거
      changePercent: 0, // 변동률 제거
      volume: priceInfo.volume || 0,
      marketCap: priceInfo.marketCap || 0,
      lastUpdate: new Date().toISOString(),
      source: 'naver-finance',
      note: '전일 종가 기준 (실시간 크롤링)'
    };

    console.log('크롤링 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('크롤링 오류:', error);
    return null;
  }
}

function extractStockName(html, symbol) {
  // 종목명 추출 - 여러 패턴 시도
  const patterns = [
    /<h2 class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<h2[^>]*>([^<]+)<\/h2>/,
    /<title>([^<]+)<\/title>/,
    /<span class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<strong[^>]*>([^<]+)<\/strong>/,
    /<em[^>]*>([^<]+)<\/em>/,
    /<h1[^>]*>([^<]+)<\/h1>/,
    /<div class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<a[^>]*href="[^"]*item[^"]*"[^>]*>([^<]+)<\/a>/,
    /<a[^>]*>([^<]+)<\/a>/,
    /<div[^>]*>([^<]+)<\/div>/,
    /<span[^>]*>([^<]+)<\/span>/,
    /<p[^>]*>([^<]+)<\/p>/,
    /<li[^>]*>([^<]+)<\/li>/,
    /<td[^>]*>([^<]+)<\/td>/,
    /<th[^>]*>([^<]+)<\/th>/,
    /<label[^>]*>([^<]+)<\/label>/,
    /<button[^>]*>([^<]+)<\/button>/,
    /<input[^>]*value="([^"]+)"/,
    /<meta[^>]*content="([^"]+)"/,
    /<script[^>]*>[\s\S]*?name["\s]*:["\s]*([^"']+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?종목명["\s]*:["\s]*([^"']+)["\s]*[\s\S]*?<\/script>/
  ];

  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match && match[1] && match[1].trim() && match[1] !== '최근조회') {
      const name = match[1].trim();
      console.log(`종목명 추출 성공: ${name}`);
      return name;
    }
  }

  console.log('종목명 추출 실패 - 기본값 사용');
  return getStockName(symbol);
}

function extractPriceInfo(html) {
  // 가격 정보 추출 - 여러 패턴 시도
  const pricePatterns = [
    // 네이버 증권 기본 패턴
    /<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/,
    /<span class="no_today"[^>]*>([^<]+)<\/span>/,
    /<em class="no_today"[^>]*>([^<]+)<\/em>/,
    /<strong class="no_today"[^>]*>([^<]+)<\/strong>/,
    /<p class="no_today"[^>]*>([^<]+)<\/p>/,
    /<span[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/span>/,
    
    // 스크립트에서 가격 추출
    /<script[^>]*>[\s\S]*?price["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?현재가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?종가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?value["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?amount["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?close["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?last["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?final["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    
    // HTML 태그에서 가격 추출
    /<td[^>]*>([\d,]+)<\/td>/,
    /<span[^>]*>([\d,]+)<\/span>/,
    /<div[^>]*>([\d,]+)<\/div>/,
    /<p[^>]*>([\d,]+)<\/p>/,
    /<em[^>]*>([\d,]+)<\/em>/,
    /<strong[^>]*>([\d,]+)<\/strong>/,
    /<b[^>]*>([\d,]+)<\/b>/,
    /<i[^>]*>([\d,]+)<\/i>/,
    /<font[^>]*>([\d,]+)<\/font>/,
    /<label[^>]*>([\d,]+)<\/label>/,
    /<button[^>]*>([\d,]+)<\/button>/,
    /<input[^>]*value="([\d,]+)"/,
    /<meta[^>]*content="([\d,]+)"/,
    
    // 테이블에서 가격 추출
    /<tr[^>]*>[\s\S]*?<td[^>]*>([\d,]+)<\/td>[\s\S]*?<\/tr>/,
    /<table[^>]*>[\s\S]*?<td[^>]*>([\d,]+)<\/td>[\s\S]*?<\/table>/,
    
    // 특정 클래스에서 가격 추출
    /<span class="[^"]*price[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*price[^"]*"[^>]*>([\d,]+)<\/div>/,
    /<span class="[^"]*amount[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*amount[^"]*"[^>]*>([\d,]+)<\/div>/,
    /<span class="[^"]*value[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*value[^"]*"[^>]*>([\d,]+)<\/div>/
  ];

  let price = null;
  let volume = 0;
  let marketCap = 0;

  // 가격 추출
  for (const pattern of pricePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const priceStr = match[1].replace(/,/g, '');
      const priceNum = parseInt(priceStr);
      if (priceNum && priceNum > 0 && priceNum < 10000000) { // 합리적인 가격 범위
        price = priceNum;
        console.log(`가격 추출 성공: ${price}`);
        break;
      }
    }
  }

  // 거래량 추출
  const volumePatterns = [
    /<span class="[^"]*tah[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<td[^>]*>([\d,]+)<\/td>/,
    /<span[^>]*>([\d,]+)<\/span>/,
    /<div[^>]*>([\d,]+)<\/div>/
  ];

  for (const pattern of volumePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const volumeStr = match[1].replace(/,/g, '');
      const volumeNum = parseInt(volumeStr);
      if (volumeNum && volumeNum > 1000) { // 합리적인 거래량 범위
        volume = volumeNum;
        console.log(`거래량 추출 성공: ${volume}`);
        break;
      }
    }
  }

  // 시가총액 추출
  const marketCapPatterns = [
    /시가총액[^>]*>([^<]+)<\/[^>]*>/,
    /시총[^>]*>([^<]+)<\/[^>]*>/,
    /<td[^>]*>([\d,]+억)<\/td>/,
    /<span[^>]*>([\d,]+억)<\/span>/,
    /<div[^>]*>([\d,]+억)<\/div>/
  ];

  for (const pattern of marketCapPatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const marketCapStr = match[1];
      if (marketCapStr.includes('억')) {
        const value = parseFloat(marketCapStr.replace(/[억,]/g, ''));
        marketCap = Math.round(value * 100000000);
        console.log(`시가총액 추출 성공: ${marketCap}`);
        break;
      } else if (marketCapStr.includes('조')) {
        const value = parseFloat(marketCapStr.replace(/[조,]/g, ''));
        marketCap = Math.round(value * 1000000000000);
        console.log(`시가총액 추출 성공: ${marketCap}`);
        break;
      }
    }
  }

  return { price, volume, marketCap };
}

function getStockName(symbol) {
  const names = {
    '005930': '삼성전자',
    '000660': 'SK하이닉스',
    '035420': 'NAVER',
    '035720': '카카오',
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
    '196800': '아이에이',
    '036200': '유니셈'
  };
  return names[symbol] || symbol;
}
