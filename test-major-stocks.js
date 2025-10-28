// 주요 종목 실시간 검색 테스트
async function testMajorStocksSearch(keyword) {
  try {
    console.log(`=== ${keyword} 주요 종목 실시간 검색 테스트 ===`);
    
    // 주요 종목 코드들
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
    
    console.log(`검색 키워드: ${keyword}`);
    console.log(`주요 종목 ${majorStockCodes.length}개 중에서 검색 중...`);
    
    for (let i = 0; i < Math.min(majorStockCodes.length, 10); i++) { // 처음 10개만 테스트
      const code = majorStockCodes[i];
      try {
        console.log(`\n${i + 1}. 종목 ${code} 조회 중...`);
        
        const priceInfo = await fetchStockPrice(code);
        if (priceInfo) {
          const stockName = await getStockName(code);
          
          if (stockName) {
            console.log(`종목명: ${stockName}`);
            
            // 키워드 매칭 확인
            if (stockName.toLowerCase().includes(lowerKeyword)) {
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
              
              console.log(`✅ 매칭된 종목: ${stockName} (${code}) - ${priceInfo.price.toLocaleString()}원`);
            } else {
              console.log(`❌ 매칭되지 않음: ${stockName}`);
            }
          } else {
            console.log(`❌ 종목명 추출 실패`);
          }
        } else {
          console.log(`❌ 가격 조회 실패`);
        }
        
        // 요청 간격 조절
        await randomDelay(500, 1000);
        
      } catch (error) {
        console.error(`종목 ${code} 조회 오류:`, error);
      }
    }
    
    console.log(`\n=== 검색 결과 ===`);
    console.log(`매칭된 종목: ${results.length}개`);
    
    results.forEach((stock, index) => {
      console.log(`${index + 1}. ${stock.name} (${stock.symbol}) - ${stock.price.toLocaleString()}원`);
    });
    
    return results;

  } catch (error) {
    console.error('검색 오류:', error);
    return [];
  }
}

async function fetchStockPrice(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
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
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: 0
      };
    }

    return null;

  } catch (error) {
    console.error(`종목 ${symbol} 가격 조회 오류:`, error);
    return null;
  }
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

function randomDelay(min, max) {
  const delay = Math.floor(Math.random() * (max - min + 1)) + min;
  return new Promise(resolve => setTimeout(resolve, delay));
}

// 테스트 실행
testMajorStocksSearch('삼성');
