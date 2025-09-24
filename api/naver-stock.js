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
    // 1. 네이버 증권에서 전일 종가 크롤링
    console.log('네이버 증권에서 전일 종가 크롤링 시도...');
    const naverData = await fetchFromNaver(symbol);
    if (naverData) {
      return res.status(200).json({
        success: true,
        data: naverData,
        source: 'naver-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 2. 카카오 증권에서 전일 종가 크롤링
    console.log('카카오 증권에서 전일 종가 크롤링 시도...');
    const kakaoData = await fetchFromKakao(symbol);
    if (kakaoData) {
      return res.status(200).json({
        success: true,
        data: kakaoData,
        source: 'kakao-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 3. 토스 증권에서 전일 종가 크롤링
    console.log('토스 증권에서 전일 종가 크롤링 시도...');
    const tossData = await fetchFromToss(symbol);
    if (tossData) {
      return res.status(200).json({
        success: true,
        data: tossData,
        source: 'toss-finance',
        timestamp: new Date().toISOString()
      });
    }

    // 4. Finup에서 전일 종가 크롤링
    console.log('Finup에서 전일 종가 크롤링 시도...');
    const finupData = await fetchFromFinup(symbol);
    if (finupData) {
      return res.status(200).json({
        success: true,
        data: finupData,
        source: 'finup',
        timestamp: new Date().toISOString()
      });
    }

    // 5. 백업: Yahoo Finance 시도
    console.log('모든 크롤링 실패, Yahoo Finance API 시도...');
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
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    console.log(`네이버 증권 크롤링: ${url}`);
    
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
    
    // 디버깅: HTML 길이와 일부 내용 확인
    console.log(`HTML 길이: ${html.length}`);
    console.log(`HTML에 'no_today' 포함 여부: ${html.includes('no_today')}`);
    console.log(`HTML에 '종목' 포함 여부: ${html.includes('종목')}`);
    console.log(`HTML에 'wrap_company' 포함 여부: ${html.includes('wrap_company')}`);
    
    // 여러 패턴으로 가격 정보 추출 시도
    let priceMatch = html.match(/<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    
    // 대안 패턴들
    if (!priceMatch) {
      priceMatch = html.match(/<span class="no_today"[^>]*>([^<]+)<\/span>/);
    }
    if (!priceMatch) {
      priceMatch = html.match(/<em class="no_today"[^>]*>([^<]+)<\/em>/);
    }
    if (!priceMatch) {
      priceMatch = html.match(/<strong class="no_today"[^>]*>([^<]+)<\/strong>/);
    }
    if (!priceMatch) {
      priceMatch = html.match(/<p class="no_today"[^>]*>([^<]+)<\/p>/);
    }
    if (!priceMatch) {
      priceMatch = html.match(/<span[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/span>/);
    }
    
    // 종목명 추출 (여러 패턴 시도)
    let nameMatch = html.match(/<h2 class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    if (!nameMatch) {
      nameMatch = html.match(/<h2[^>]*>([^<]+)<\/h2>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<title>([^<]+)<\/title>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<span class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<div class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<strong[^>]*>([^<]+)<\/strong>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<em[^>]*>([^<]+)<\/em>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<div class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<span class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<div class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<span class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<div class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<span class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<a[^>]*href="[^"]*item[^"]*"[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<a[^>]*>([^<]+)<\/a>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<div[^>]*>([^<]+)<\/div>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<span[^>]*>([^<]+)<\/span>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<p[^>]*>([^<]+)<\/p>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<li[^>]*>([^<]+)<\/li>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<td[^>]*>([^<]+)<\/td>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<th[^>]*>([^<]+)<\/th>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<label[^>]*>([^<]+)<\/label>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<button[^>]*>([^<]+)<\/button>/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<input[^>]*value="([^"]+)"/);
    }
    if (!nameMatch) {
      nameMatch = html.match(/<meta[^>]*content="([^"]+)"/);
    }
    
    // 변동 정보 추출
    const changeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d,]+)<\/span>/);
    const changePercentMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([+-]?[\d.]+)%<\/span>/);
    const volumeMatch = html.match(/<span class="[^"]*tah[^"]*"[^>]*>([\d,]+)<\/span>/);
    
    if (!priceMatch) {
      console.log('네이버에서 가격 정보를 찾을 수 없습니다');
      console.log('HTML 샘플:', html.substring(0, 1000));
      return null;
    }

    // 종목명 추출 실패 시 디버깅
    if (!nameMatch) {
      console.log('종목명 추출 실패 - getStockName 사용');
      console.log('HTML에서 종목명 관련 부분:', html.match(/<h2[^>]*>.*?<\/h2>/g) || '없음');
      console.log('HTML에서 wrap_company 관련 부분:', html.match(/<[^>]*wrap_company[^>]*>.*?<\/[^>]*>/g) || '없음');
      console.log('HTML에서 company 관련 부분:', html.match(/<[^>]*company[^>]*>.*?<\/[^>]*>/g) || '없음');
      console.log('HTML에서 stock_name 관련 부분:', html.match(/<[^>]*stock_name[^>]*>.*?<\/[^>]*>/g) || '없음');
      console.log('HTML에서 name 관련 부분:', html.match(/<[^>]*name[^>]*>.*?<\/[^>]*>/g) || '없음');
      console.log('HTML에서 title 관련 부분:', html.match(/<title>.*?<\/title>/g) || '없음');
      console.log('HTML에서 h1 관련 부분:', html.match(/<h1[^>]*>.*?<\/h1>/g) || '없음');
      console.log('HTML에서 h2 관련 부분:', html.match(/<h2[^>]*>.*?<\/h2>/g) || '없음');
      console.log('HTML에서 strong 관련 부분:', html.match(/<strong[^>]*>.*?<\/strong>/g) || '없음');
      console.log('HTML에서 em 관련 부분:', html.match(/<em[^>]*>.*?<\/em>/g) || '없음');
      console.log('HTML에서 a 태그 관련 부분:', html.match(/<a[^>]*>.*?<\/a>/g) || '없음');
      console.log('HTML에서 div 태그 관련 부분:', html.match(/<div[^>]*>.*?<\/div>/g) || '없음');
      console.log('HTML에서 span 태그 관련 부분:', html.match(/<span[^>]*>.*?<\/span>/g) || '없음');
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
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
      source: 'naver-finance'
    };

    console.log('네이버 증권 크롤링 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('네이버 증권 크롤링 오류:', error);
    return null;
  }
}

async function fetchFromKakao(symbol) {
  try {
    // 카카오 증권 API 또는 웹사이트 크롤링
    const url = `https://stock.kakao.com/stock/${symbol}`;
    
    console.log(`카카오 증권 크롤링: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      }
    });

    if (!response.ok) {
      console.log(`카카오 증권 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 카카오 증권 페이지 구조에 맞는 정규식
    const priceMatch = html.match(/<span[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/span>/);
    const nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
    
    if (!priceMatch) {
      console.log('카카오 증권에서 가격 정보를 찾을 수 없습니다');
      return null;
    }

    const price = parseInt(priceMatch[1].replace(/,/g, ''));
    const name = nameMatch ? nameMatch[1].trim() : getStockName(symbol);

    if (isNaN(price)) {
      console.log('카카오 증권 가격 파싱 실패:', priceMatch[1]);
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: name,
      price: price,
      change: 0,
      changePercent: 0,
      volume: 0,
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
      source: 'kakao-finance'
    };

    console.log('카카오 증권 크롤링 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('카카오 증권 크롤링 오류:', error);
    return null;
  }
}

async function fetchFromToss(symbol) {
  try {
    // 토스 증권 API 또는 웹사이트 크롤링
    const url = `https://toss.im/investment/stocks/${symbol}`;
    
    console.log(`토스 증권 크롤링: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      }
    });

    if (!response.ok) {
      console.log(`토스 증권 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 토스 증권 페이지 구조에 맞는 정규식
    const priceMatch = html.match(/<span[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/span>/);
    const nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
    
    if (!priceMatch) {
      console.log('토스 증권에서 가격 정보를 찾을 수 없습니다');
      return null;
    }

    const price = parseInt(priceMatch[1].replace(/,/g, ''));
    const name = nameMatch ? nameMatch[1].trim() : getStockName(symbol);

    if (isNaN(price)) {
      console.log('토스 증권 가격 파싱 실패:', priceMatch[1]);
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: name,
      price: price,
      change: 0,
      changePercent: 0,
      volume: 0,
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
      source: 'toss-finance'
    };

    console.log('토스 증권 크롤링 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('토스 증권 크롤링 오류:', error);
    return null;
  }
}

async function fetchFromFinup(symbol) {
  try {
    // Finup API 또는 웹사이트 크롤링
    const url = `https://finup.co.kr/stock/${symbol}`;
    
    console.log(`Finup 크롤링: ${url}`);
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      }
    });

    if (!response.ok) {
      console.log(`Finup 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // Finup 페이지 구조에 맞는 정규식
    const priceMatch = html.match(/<span[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/span>/);
    const nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
    
    if (!priceMatch) {
      console.log('Finup에서 가격 정보를 찾을 수 없습니다');
      return null;
    }

    const price = parseInt(priceMatch[1].replace(/,/g, ''));
    const name = nameMatch ? nameMatch[1].trim() : getStockName(symbol);

    if (isNaN(price)) {
      console.log('Finup 가격 파싱 실패:', priceMatch[1]);
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: name,
      price: price,
      change: 0,
      changePercent: 0,
      volume: 0,
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
      source: 'finup'
    };

    console.log('Finup 크롤링 성공:', stockData);
    return stockData;

  } catch (error) {
    console.error('Finup 크롤링 오류:', error);
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
    '196800': '아이에이',
    '036200': '유니셈'
  };
  return names[symbol] || symbol;
}

