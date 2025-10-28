// Vercel API 핸들러 - 실시간 주가 크롤링
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
    console.log(`실시간 종목 검색: ${keyword}`);
    
    // 실시간 주가 검색 실행
    const searchResults = await searchStocksRealtime(keyword, limit);
    
    if (searchResults.length > 0) {
      return res.status(200).json({
        success: true,
        keyword: keyword,
        count: searchResults.length,
        data: searchResults,
        timestamp: new Date().toISOString(),
        source: 'realtime-crawling'
      });
    }

    return res.status(404).json({
      success: false,
      error: '검색 결과가 없습니다'
    });

  } catch (error) {
    console.error('실시간 종목 검색 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function searchStocksRealtime(keyword, limit) {
  try {
    console.log(`실시간 종목 검색 시작: ${keyword}`);
    
    // 네이버 증권에서 실시간 검색
    const searchResults = await searchNaverFinance(keyword, limit);
    
    console.log(`실시간 검색 결과: ${searchResults.length}개`);
    return searchResults;

  } catch (error) {
    console.error('실시간 종목 검색 오류:', error);
    return [];
  }
}

async function searchNaverFinance(keyword, limit) {
  try {
    console.log(`실시간 네이버 증권 검색: ${keyword}`);
    
    // 바로 웹 검색 사용 (더 안정적)
    return await searchNaverWeb(keyword, limit);

  } catch (error) {
    console.error('네이버 증권 검색 오류:', error);
    return [];
  }
}

async function searchNaverWeb(keyword, limit) {
  try {
    console.log(`실시간 주식 검색: ${keyword}`);
    
    // 키워드가 종목코드인 경우 직접 조회
    if (/^\d{6}$/.test(keyword)) {
      console.log(`종목코드 직접 조회: ${keyword}`);
      const priceInfo = await fetchStockPrice(keyword);
      if (priceInfo) {
        return [{
          symbol: keyword,
          name: '종목코드검색',
          market: keyword.startsWith('0') ? 'KOSDAQ' : 'KOSPI',
          price: priceInfo.price,
          change: priceInfo.change || 0,
          changePercent: priceInfo.changePercent || 0,
          volume: priceInfo.volume || 0,
          marketCap: priceInfo.marketCap || 0,
          lastUpdate: new Date().toISOString(),
          source: 'naver-direct-search',
          note: '실시간 크롤링 데이터'
        }];
      }
    }
    
    // 일반 검색의 경우 - 네이버 증권 메인 페이지에서 실시간 데이터 조회
    console.log(`네이버 증권 메인 페이지에서 실시간 데이터 조회: ${keyword}`);
    
    // 네이버 증권 메인 페이지 접근
    const mainUrl = `https://finance.naver.com/`;
    
    const response = await fetch(mainUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'DNT': '1'
      }
    });

    if (!response.ok) {
      console.log(`네이버 증권 접근 오류: ${response.status}`);
      return [];
    }

    const html = await response.text();
    console.log(`네이버 증권 HTML 길이: ${html.length}`);
    
    // 실시간 검색을 위해 주요 종목들을 직접 조회
    const majorStocks = await searchMajorStocks(keyword, limit);
    
    if (majorStocks.length > 0) {
      console.log(`주요 종목 검색 결과: ${majorStocks.length}개`);
      return majorStocks;
    }
    
    // 주요 종목에서 찾지 못한 경우, 일반 검색 시도
    console.log('일반 검색 시도...');
    return await searchGeneralStocks(keyword, limit);

  } catch (error) {
    console.error('실시간 검색 오류:', error);
    return [];
  }
}

async function searchMajorStocks(keyword, limit) {
  // 주요 종목들의 실시간 검색
  const majorStockCodes = [
    '005930', // 삼성전자
    '000660', // SK하이닉스
    '035420', // 네이버
    '035720', // 카카오
    '005380', // 현대차
    '000270', // 기아
    '051910', // LG화학
    '068270', // 셀트리온
    '096350', // 대창솔루션
    '065450', // 빅텍
    '086520', // 에코프로
    '323410', // 카카오뱅크
    '373220', // LG에너지솔루션
    '207940', // 삼성바이오로직스
    '006400', // 삼성SDI
    '017670', // SK텔레콤
    '030200', // KT
    '034730', // SK
    '003550', // LG
    '005490', // 포스코
    '015760', // 한국전력
    '055550', // 신한지주
    '105560', // KB금융
    '086790', // 하나금융지주
    '012330', // 현대모비스
    '086280', // 현대글로비스
    '000720', // 현대건설
    '267250', // HD현대중공업
    '004020', // 현대제철
    '066570', // LG전자
    '034220', // LG디스플레이
    '032640', // LG유플러스
    '051900', // LG생활건강
    '096770', // SK이노베이션
    '402340', // SK스퀘어
    '326030', // SK바이오팜
    '377300', // 카카오페이
    '293490', // 카카오게임즈
    '357780', // 카카오모빌리티
    '091990', // 셀트리온헬스케어
    '078930', // GS
    '009830', // 한화솔루션
    '034020', // 두산에너빌리티
    '042700', // 한미반도체
    '047050', // 포스코인터내셔널
    '036460', // 한국가스공사
    '097950', // CJ제일제당
    '247540', // 에코프로비엠
    '196170', // 알테오젠
    '066970', // 엘앤에프
    '196300', // 에이치엘비
    '196490', // 다이나믹디자인
    '196700', // 웹젠
    '196800', // 아이에이
    '036200'  // 유니셈
  ];

  const results = [];
  const lowerKeyword = keyword.toLowerCase();
  
  for (const code of majorStockCodes) {
    try {
      const priceInfo = await fetchStockPrice(code);
      if (priceInfo) {
        // 종목명 추출 (간단한 방법)
        const stockName = await getStockName(code);
        
        // 키워드 매칭 확인
        if (stockName && stockName.toLowerCase().includes(lowerKeyword)) {
          results.push({
            symbol: code,
            name: stockName,
            market: code.startsWith('0') ? 'KOSDAQ' : 'KOSPI',
            price: priceInfo.price,
            change: priceInfo.change || 0,
            changePercent: priceInfo.changePercent || 0,
            volume: priceInfo.volume || 0,
            marketCap: priceInfo.marketCap || 0,
            lastUpdate: new Date().toISOString(),
            source: 'naver-major-stocks',
            note: '실시간 크롤링 데이터'
          });
          
          console.log(`매칭된 종목: ${stockName} (${code}) - ${priceInfo.price}원`);
          
          if (results.length >= limit) {
            break;
          }
        }
      }
    } catch (error) {
      console.error(`종목 ${code} 조회 오류:`, error);
    }
  }
  
  return results;
}

async function getStockName(code) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${code}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://finance.naver.com/',
        'DNT': '1'
      }
    });

    if (!response.ok) {
      return null;
    }

    const html = await response.text();
    
    // 종목명 추출
    const namePatterns = [
      /<h2[^>]*>([^<]+)<\/h2>/,
      /<title[^>]*>([^<]+)<\/title>/,
      /<h1[^>]*>([^<]+)<\/h1>/
    ];

    for (const pattern of namePatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const name = match[1].trim();
        if (name && name.length > 0 && name.length < 50) {
          return name;
        }
      }
    }

    return null;

  } catch (error) {
    console.error(`종목명 조회 오류:`, error);
    return null;
  }
}

async function searchGeneralStocks(keyword, limit) {
  // 일반 검색은 현재 비활성화 (네이버 검색 페이지 500 오류)
  console.log('일반 검색은 현재 비활성화됨');
  return [];
}

// 하드코딩된 데이터베이스 제거 - 이제 진짜 실시간 검색만 사용

async function fetchStockPrice(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    // 랜덤 지연 (봇 탐지 회피)
    await randomDelay(1000, 3000);
    
    // 다양한 User-Agent 로테이션
    const userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15'
    ];
    
    const randomUA = userAgents[Math.floor(Math.random() * userAgents.length)];
    
    const options = {
      method: 'GET',
      headers: {
        'User-Agent': randomUA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7,ja;q=0.6',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Upgrade-Insecure-Requests': '1',
        'Connection': 'keep-alive',
        'Referer': 'https://finance.naver.com/',
        'DNT': '1'
      },
      // 타임아웃 설정
      signal: AbortSignal.timeout(10000)
    };

    let response;
    try {
      // 직접 요청 시도
      response = await fetch(url, options);
    } catch (error) {
      console.log('직접 요청 실패, 프록시 시도:', error.message);
      // 프록시 서버 사용
      response = await fetchWithProxy(url, options);
    }

    if (!response.ok) {
      console.log(`HTTP 오류: ${response.status} ${response.statusText}`);
      return null;
    }

    const html = await response.text();
    
    // 응답이 봇 차단 페이지인지 확인
    if (isBlockedPage(html)) {
      console.log('봇 차단 페이지 감지됨');
      return null;
    }
    
    // 가격 정보 추출
    const pricePatterns = [
      /<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/,
      /<span class="no_today"[^>]*>([^<]+)<\/span>/,
      /<em class="no_today"[^>]*>([^<]+)<\/em>/,
      /<strong class="no_today"[^>]*>([^<]+)<\/strong>/
    ];

    let price = null;
    for (const pattern of pricePatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const priceStr = match[1].replace(/,/g, '');
        const priceNum = parseInt(priceStr);
        if (priceNum && priceNum > 0 && priceNum < 10000000) {
          price = priceNum;
          break;
        }
      }
    }

    if (price) {
      return {
        price: price,
        change: 0, // 변동가 정보는 별도 추출 필요
        changePercent: 0, // 변동률 정보는 별도 추출 필요
        volume: 0, // 거래량 정보는 별도 추출 필요
        marketCap: 0 // 시가총액 정보는 별도 추출 필요
      };
    }

    return null;

  } catch (error) {
    console.error(`종목 ${symbol} 가격 조회 오류:`, error);
    return null;
  }
}

// 랜덤 지연 함수 (봇 탐지 회피)
function randomDelay(min, max) {
  const delay = Math.floor(Math.random() * (max - min + 1)) + min;
  return new Promise(resolve => setTimeout(resolve, delay));
}

// 봇 차단 페이지 감지
function isBlockedPage(html) {
  const blockIndicators = [
    '접근이 차단되었습니다',
    '자동화된 요청',
    '봇 감지',
    'captcha',
    'cloudflare',
    'access denied',
    'blocked',
    'forbidden',
    'too many requests',
    'rate limit',
    'security check',
    'verification required'
  ];
  
  const lowerHtml = html.toLowerCase();
  return blockIndicators.some(indicator => lowerHtml.includes(indicator));
}

// 프록시 서버 사용 (필요시)
async function fetchWithProxy(url, options) {
  const proxyUrls = [
    'https://api.codetabs.com/v1/proxy?quest=',
    'https://cors-anywhere.herokuapp.com/',
    'https://api.allorigins.win/raw?url='
  ];
  
  for (const proxyUrl of proxyUrls) {
    try {
      const proxyRequestUrl = proxyUrl + encodeURIComponent(url);
      const response = await fetch(proxyRequestUrl, options);
      
      if (response.ok) {
        return response;
      }
    } catch (error) {
      console.log(`프록시 ${proxyUrl} 실패:`, error.message);
      continue;
    }
  }
  
  throw new Error('모든 프록시 서버 실패');
}

// Vercel에서는 export default만 사용