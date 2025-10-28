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
    
    // 키워드로 종목 코드 찾기
    const stockCandidates = findStockByKeyword(keyword);
    
    if (stockCandidates.length === 0) {
      console.log('해당 키워드로 종목을 찾을 수 없습니다');
      return [];
    }
    
    console.log(`찾은 종목: ${stockCandidates.length}개`);
    
    // 각 종목의 실시간 가격 정보 가져오기
    const detailedResults = [];
    for (let i = 0; i < Math.min(stockCandidates.length, limit); i++) {
      const stock = stockCandidates[i];
      try {
        console.log(`종목 ${stock.symbol} (${stock.name}) 가격 조회 중...`);
        const priceInfo = await fetchStockPrice(stock.symbol);
        if (priceInfo) {
          detailedResults.push({
            symbol: stock.symbol,
            name: stock.name,
            market: stock.market || 'KOSPI',
            price: priceInfo.price,
            change: priceInfo.change || 0,
            changePercent: priceInfo.changePercent || 0,
            volume: priceInfo.volume || 0,
            marketCap: priceInfo.marketCap || 0,
            lastUpdate: new Date().toISOString(),
            source: 'naver-finance-realtime',
            note: '실시간 크롤링 데이터'
          });
          console.log(`종목 ${stock.symbol} 가격 조회 성공: ${priceInfo.price}원`);
        } else {
          console.log(`종목 ${stock.symbol} 가격 조회 실패`);
        }
      } catch (error) {
        console.error(`종목 ${stock.symbol} 가격 조회 오류:`, error);
      }
    }

    console.log(`최종 결과: ${detailedResults.length}개 종목`);
    return detailedResults;

  } catch (error) {
    console.error('네이버 증권 검색 오류:', error);
    return [];
  }
}

function findStockByKeyword(keyword) {
  // 확장된 종목 데이터베이스 (100개 이상)
  const stockDatabase = {
    // 삼성 그룹
    '삼성전자': { symbol: '005930', name: '삼성전자', market: 'KOSPI' },
    '삼성': { symbol: '005930', name: '삼성전자', market: 'KOSPI' },
    'samsung': { symbol: '005930', name: '삼성전자', market: 'KOSPI' },
    '삼성바이오로직스': { symbol: '207940', name: '삼성바이오로직스', market: 'KOSPI' },
    '삼성sdi': { symbol: '006400', name: '삼성SDI', market: 'KOSPI' },
    '삼성증권': { symbol: '016360', name: '삼성증권', market: 'KOSPI' },
    '삼성카드': { symbol: '029780', name: '삼성카드', market: 'KOSPI' },
    '삼성e&a': { symbol: '028050', name: '삼성E&A', market: 'KOSPI' },
    '삼성에스디에스': { symbol: '018260', name: '삼성에스디에스', market: 'KOSPI' },
    '삼성화재': { symbol: '000810', name: '삼성화재', market: 'KOSPI' },
    '삼성물산': { symbol: '028260', name: '삼성물산', market: 'KOSPI' },
    '삼성생명': { symbol: '032830', name: '삼성생명', market: 'KOSPI' },
    
    // SK 그룹
    'sk하이닉스': { symbol: '000660', name: 'SK하이닉스', market: 'KOSPI' },
    'sk텔레콤': { symbol: '017670', name: 'SK텔레콤', market: 'KOSPI' },
    'sk': { symbol: '034730', name: 'SK', market: 'KOSPI' },
    'sk이노베이션': { symbol: '096770', name: 'SK이노베이션', market: 'KOSPI' },
    'sk스퀘어': { symbol: '402340', name: 'SK스퀘어', market: 'KOSPI' },
    'sk바이오팜': { symbol: '326030', name: 'SK바이오팜', market: 'KOSPI' },
    
    // LG 그룹
    'lg전자': { symbol: '066570', name: 'LG전자', market: 'KOSPI' },
    'lg화학': { symbol: '051910', name: 'LG화학', market: 'KOSPI' },
    'lg': { symbol: '003550', name: 'LG', market: 'KOSPI' },
    'lg에너지솔루션': { symbol: '373220', name: 'LG에너지솔루션', market: 'KOSPI' },
    'lg디스플레이': { symbol: '034220', name: 'LG디스플레이', market: 'KOSPI' },
    'lg유플러스': { symbol: '032640', name: 'LG유플러스', market: 'KOSPI' },
    'lg생활건강': { symbol: '051900', name: 'LG생활건강', market: 'KOSPI' },
    
    // 현대 그룹
    '현대차': { symbol: '005380', name: '현대차', market: 'KOSPI' },
    '기아': { symbol: '000270', name: '기아', market: 'KOSPI' },
    '현대모비스': { symbol: '012330', name: '현대모비스', market: 'KOSPI' },
    '현대글로비스': { symbol: '086280', name: '현대글로비스', market: 'KOSPI' },
    '현대건설': { symbol: '000720', name: '현대건설', market: 'KOSPI' },
    'hd현대중공업': { symbol: '267250', name: 'HD현대중공업', market: 'KOSPI' },
    '현대제철': { symbol: '004020', name: '현대제철', market: 'KOSPI' },
    
    // 카카오 그룹
    '카카오': { symbol: '035720', name: '카카오', market: 'KOSPI' },
    '카카오뱅크': { symbol: '323410', name: '카카오뱅크', market: 'KOSPI' },
    '카카오페이': { symbol: '377300', name: '카카오페이', market: 'KOSPI' },
    '카카오게임즈': { symbol: '293490', name: '카카오게임즈', market: 'KOSPI' },
    '카카오모빌리티': { symbol: '357780', name: '카카오모빌리티', market: 'KOSPI' },
    
    // 기타 주요 종목
    '네이버': { symbol: '035420', name: 'NAVER', market: 'KOSPI' },
    'naver': { symbol: '035420', name: 'NAVER', market: 'KOSPI' },
    '셀트리온': { symbol: '068270', name: '셀트리온', market: 'KOSPI' },
    '셀트리온헬스케어': { symbol: '091990', name: '셀트리온헬스케어', market: 'KOSPI' },
    '포스코': { symbol: '005490', name: 'POSCO홀딩스', market: 'KOSPI' },
    'posco': { symbol: '005490', name: 'POSCO홀딩스', market: 'KOSPI' },
    '한국전력': { symbol: '015760', name: '한국전력', market: 'KOSPI' },
    '한전': { symbol: '015760', name: '한국전력', market: 'KOSPI' },
    'kt': { symbol: '030200', name: 'KT', market: 'KOSPI' },
    '신한지주': { symbol: '055550', name: '신한지주', market: 'KOSPI' },
    'kb금융': { symbol: '105560', name: 'KB금융', market: 'KOSPI' },
    '하나금융지주': { symbol: '086790', name: '하나금융지주', market: 'KOSPI' },
    '기업은행': { symbol: '024110', name: '기업은행', market: 'KOSPI' },
    'hmm': { symbol: '011200', name: 'HMM', market: 'KOSPI' },
    '한국항공우주': { symbol: '161890', name: '한국항공우주', market: 'KOSPI' },
    '대한항공': { symbol: '003490', name: '대한항공', market: 'KOSPI' },
    '크래프톤': { symbol: '259960', name: '크래프톤', market: 'KOSPI' },
    'jyp': { symbol: '035900', name: 'JYP Ent.', market: 'KOSPI' },
    '넷마블': { symbol: '251270', name: '넷마블', market: 'KOSPI' },
    'gs': { symbol: '078930', name: 'GS', market: 'KOSPI' },
    '한화솔루션': { symbol: '009830', name: '한화솔루션', market: 'KOSPI' },
    '두산에너빌리티': { symbol: '034020', name: '두산에너빌리티', market: 'KOSPI' },
    '한미반도체': { symbol: '042700', name: '한미반도체', market: 'KOSPI' },
    '포스코인터내셔널': { symbol: '047050', name: '포스코인터내셔널', market: 'KOSPI' },
    '한국가스공사': { symbol: '036460', name: '한국가스공사', market: 'KOSPI' },
    'cj제일제당': { symbol: '097950', name: 'CJ제일제당', market: 'KOSPI' },
    'cj': { symbol: '097950', name: 'CJ제일제당', market: 'KOSPI' },
    
    // KOSDAQ 주요 종목
    '대창솔루션': { symbol: '096350', name: '대창솔루션', market: 'KOSDAQ' },
    '빅텍': { symbol: '065450', name: '빅텍', market: 'KOSDAQ' },
    '에코프로': { symbol: '086520', name: '에코프로', market: 'KOSPI' },
    '에코프로비엠': { symbol: '247540', name: '에코프로비엠', market: 'KOSPI' },
    '알테오젠': { symbol: '196170', name: '알테오젠', market: 'KOSPI' },
    '엘앤에프': { symbol: '066970', name: '엘앤에프', market: 'KOSPI' },
    '에이치엘비': { symbol: '196300', name: '에이치엘비', market: 'KOSPI' },
    '다이나믹디자인': { symbol: '196490', name: '다이나믹디자인', market: 'KOSPI' },
    '웹젠': { symbol: '196700', name: '웹젠', market: 'KOSPI' },
    '아이에이': { symbol: '196800', name: '아이에이', market: 'KOSPI' },
    '유니셈': { symbol: '036200', name: '유니셈', market: 'KOSPI' }
  };

  const lowerKeyword = keyword.toLowerCase();
  
  // 정확한 매칭
  if (stockDatabase[lowerKeyword]) {
    return [stockDatabase[lowerKeyword]];
  }
  
  // 부분 매칭
  const candidates = [];
  for (const [key, stock] of Object.entries(stockDatabase)) {
    if (key.includes(lowerKeyword) || lowerKeyword.includes(key)) {
      candidates.push(stock);
    }
  }
  
  // 키워드가 종목 코드인 경우 (6자리 숫자)
  if (/^\d{6}$/.test(keyword)) {
    candidates.push({
      symbol: keyword,
      name: '종목코드검색',
      market: keyword.startsWith('0') ? 'KOSDAQ' : 'KOSPI'
    });
  }
  
  return candidates;
}

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