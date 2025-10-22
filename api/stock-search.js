// import fetch from 'node-fetch'; // Vercel에서는 내장 fetch 사용

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const { keyword, limit = 10 } = req.query;

  if (!keyword) {
    return res.status(400).json({
      success: false,
      error: '검색어가 필요합니다'
    });
  }

  try {
    console.log(`종목 검색: ${keyword}`);
    
    // 네이버 증권에서 종목 검색
    const searchResults = await searchStocks(keyword, limit);
    
    if (searchResults.length > 0) {
      return res.status(200).json({
        success: true,
        keyword: keyword,
        count: searchResults.length,
        data: searchResults,
        timestamp: new Date().toISOString()
      });
    }

    return res.status(404).json({
      success: false,
      error: '검색 결과가 없습니다'
    });

  } catch (error) {
    console.error('종목 검색 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function searchStocks(keyword, limit) {
  try {
    console.log(`실시간 종목 검색 시작: ${keyword}`);
    
    // KRX 데이터베이스에서 검색
    const fs = require('fs');
    const path = require('path');
    
    // KRX 데이터 파일 경로
    const krxDataPath = path.join(process.cwd(), 'assets', 'data', 'krx_basic_info.json');
    
    let krxData = null;
    try {
      const dataFile = fs.readFileSync(krxDataPath, 'utf8');
      krxData = JSON.parse(dataFile);
      console.log(`KRX 데이터 로드 완료: ${krxData.stocks?.length || 0}개 종목`);
    } catch (error) {
      console.error('KRX 데이터 로드 실패:', error.message);
      // 폴백: 주요 종목 목록 사용
      return await searchFromMajorStocks(keyword, limit);
    }

    if (!krxData || !krxData.stocks || !Array.isArray(krxData.stocks)) {
      console.log('KRX 데이터가 유효하지 않음 - 주요 종목으로 폴백');
      return await searchFromMajorStocks(keyword, limit);
    }

    // 키워드와 일치하는 종목 찾기 (대소문자 구분 없이)
    const searchKeyword = keyword.toLowerCase();
    const matches = krxData.stocks.filter(stock => {
      const name = (stock.name || '').toLowerCase();
      const code = (stock.code || '').toLowerCase();
      const market = (stock.market || '').toLowerCase();
      const sector = (stock.sector || '').toLowerCase();
      
      return name.includes(searchKeyword) || 
             code.includes(searchKeyword) ||
             market.includes(searchKeyword) ||
             sector.includes(searchKeyword) ||
             searchKeyword.includes(name) ||
             searchKeyword.includes(code);
    }).slice(0, limit);

    console.log(`KRX 데이터베이스 검색 결과: ${matches.length}개`);

    // 각 종목의 실시간 데이터 가져오기
    const results = [];
    for (const stock of matches) {
      try {
        // KRX 데이터에서 기본 정보 가져오기
        const stockInfo = {
          symbol: stock.code,
          name: stock.name,
          market: stock.market || 'KOSPI',
          sector: stock.sector || '기타',
          price: stock.current_price || 0,
          change: stock.change || 0,
          changePercent: stock.change_rate || 0,
          volume: stock.volume || 0,
          marketCap: stock.market_cap || 0,
          lastUpdate: stock.updated_at || new Date().toISOString(),
          source: 'krx-database',
          note: 'KRX 데이터베이스'
        };

        // 실시간 데이터 시도 (선택적)
        try {
          const realtimeData = await fetchStockData(stock.code);
          if (realtimeData && realtimeData.price > 0) {
            stockInfo.price = realtimeData.price;
            stockInfo.change = realtimeData.change;
            stockInfo.changePercent = realtimeData.changePercent;
            stockInfo.volume = realtimeData.volume;
            stockInfo.marketCap = realtimeData.marketCap;
            stockInfo.lastUpdate = realtimeData.lastUpdate;
            stockInfo.source = 'realtime-crawling';
            stockInfo.note = '실시간 크롤링';
          }
        } catch (realtimeError) {
          console.log(`${stock.code} 실시간 데이터 실패, 기본 데이터 사용: ${realtimeError.message}`);
        }

        results.push(stockInfo);
      } catch (error) {
        console.error(`${stock.code} 처리 실패:`, error);
        // 실패해도 기본 정보는 포함
        results.push({
          symbol: stock.code,
          name: stock.name,
          market: stock.market || 'KOSPI',
          sector: stock.sector || '기타',
          price: stock.current_price || 0,
          change: stock.change || 0,
          changePercent: stock.change_rate || 0,
          volume: stock.volume || 0,
          marketCap: stock.market_cap || 0,
          lastUpdate: stock.updated_at || new Date().toISOString(),
          source: 'krx-database',
          note: '기본 데이터'
        });
      }
    }

    return results;

  } catch (error) {
    console.error('종목 검색 오류:', error);
    return [];
  }
}

// 폴백: 주요 종목 목록에서 검색
async function searchFromMajorStocks(keyword, limit) {
  console.log('주요 종목 목록에서 검색:', keyword);
  
  // 주요 종목 코드 목록 (폴백용)
  const majorStocks = [
    { code: '005930', name: '삼성전자' },
    { code: '000660', name: 'SK하이닉스' },
    { code: '035420', name: 'NAVER' },
    { code: '035720', name: '카카오' },
    { code: '207940', name: '삼성바이오로직스' },
    { code: '006400', name: '삼성SDI' },
    { code: '051910', name: 'LG화학' },
    { code: '068270', name: '셀트리온' },
    { code: '323410', name: '카카오뱅크' },
    { code: '000270', name: '기아' },
    { code: '005490', name: 'POSCO홀딩스' },
    { code: '017670', name: 'SK텔레콤' },
    { code: '105560', name: 'KB금융' },
    { code: '055550', name: '신한지주' },
    { code: '096770', name: 'SK이노베이션' },
    { code: '066570', name: 'LG전자' },
    { code: '003550', name: 'LG' },
    { code: '018260', name: '삼성에스디에스' },
    { code: '015760', name: '한국전력' },
    { code: '012330', name: '현대모비스' },
    { code: '000810', name: '삼성화재' },
    { code: '086280', name: '현대글로비스' },
    { code: '028260', name: '삼성물산' },
    { code: '032830', name: '삼성생명' },
    { code: '003670', name: '포스코홀딩스' },
    { code: '024110', name: '기업은행' },
    { code: '030200', name: 'KT' },
    { code: '011200', name: 'HMM' },
    { code: '086790', name: '하나금융지주' },
    { code: '377300', name: '카카오페이' },
    { code: '161890', name: '한국항공우주' },
    { code: '034730', name: 'SK' },
    { code: '003490', name: '대한항공' },
    { code: '259960', name: '크래프톤' },
    { code: '035900', name: 'JYP Ent.' },
    { code: '251270', name: '넷마블' },
    { code: '091990', name: '셀트리온헬스케어' },
    { code: '078930', name: 'GS' },
    { code: '000720', name: '현대건설' },
    { code: '267250', name: 'HD현대중공업' },
    { code: '042700', name: '한미반도체' },
    { code: '047050', name: '포스코인터내셔널' },
  ];

  // 키워드와 일치하는 종목 찾기
  const matches = majorStocks.filter(stock => 
    stock.name.includes(keyword) || 
    stock.code.includes(keyword) ||
    keyword.includes(stock.name) ||
    keyword.includes(stock.code)
  ).slice(0, limit);

  console.log(`주요 종목 검색 결과: ${matches.length}개`);

  // 각 종목의 실시간 데이터 가져오기
  const results = [];
  for (const stock of matches) {
    try {
      const stockData = await fetchStockData(stock.code);
      if (stockData) {
        results.push({
          ...stockData,
          symbol: stock.code,
          name: stock.name
        });
      }
    } catch (error) {
      console.error(`${stock.code} 데이터 가져오기 실패:`, error);
      // 실패해도 기본 정보는 포함
      results.push({
        symbol: stock.code,
        name: stock.name,
        price: 0,
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: 0,
        lastUpdate: new Date().toISOString(),
        source: 'major-stocks-fallback',
        note: '주요 종목 폴백'
      });
    }
  }

  return results;
}

async function fetchStockData(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
      timeout: 10000
    });

    if (!response.ok) {
      console.log(`네이버 응답 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 가격 정보 추출
    const priceInfo = extractPriceInfo(html);
    
    if (!priceInfo.price) {
      console.log(`${symbol} 가격 정보를 찾을 수 없습니다`);
      return null;
    }

    const stockData = {
      symbol: symbol,
      name: getStockName(symbol),
      price: priceInfo.price,
      change: 0,
      changePercent: 0,
      volume: priceInfo.volume || 0,
      marketCap: priceInfo.marketCap || 0,
      lastUpdate: new Date().toISO8601String(),
      source: 'naver-finance',
      note: '실시간 크롤링'
    };

    console.log(`${symbol} 크롤링 성공:`, stockData);
    return stockData;

  } catch (error) {
    console.error(`${symbol} 크롤링 오류:`, error);
    return null;
  }
}

function extractPriceInfo(html) {
  // 가격 정보 추출
  const pricePatterns = [
    /<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/,
    /<span class="no_today"[^>]*>([^<]+)<\/span>/,
    /<em class="no_today"[^>]*>([^<]+)<\/em>/,
    /<strong class="no_today"[^>]*>([^<]+)<\/strong>/,
    /<script[^>]*>[\s\S]*?price["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?현재가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/
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
      if (priceNum && priceNum > 0 && priceNum < 10000000) {
        price = priceNum;
        console.log(`가격 추출 성공: ${price}`);
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
    '005490': 'POSCO홀딩스',
    '017670': 'SK텔레콤',
    '105560': 'KB금융',
    '055550': '신한지주',
    '096770': 'SK이노베이션',
    '066570': 'LG전자',
    '003550': 'LG',
    '018260': '삼성에스디에스',
    '015760': '한국전력',
    '012330': '현대모비스',
    '000810': '삼성화재',
    '086280': '현대글로비스',
    '028260': '삼성물산',
    '032830': '삼성생명',
    '003670': '포스코홀딩스',
    '024110': '기업은행',
    '030200': 'KT',
    '011200': 'HMM',
    '086790': '하나금융지주',
    '377300': '카카오페이',
    '161890': '한국항공우주',
    '034730': 'SK',
    '003490': '대한항공',
    '259960': '크래프톤',
    '035900': 'JYP Ent.',
    '251270': '넷마블',
    '091990': '셀트리온헬스케어',
    '078930': 'GS',
    '000720': '현대건설',
    '267250': 'HD현대중공업',
    '042700': '한미반도체',
    '047050': '포스코인터내셔널',
  };
  return names[symbol] || symbol;
}
