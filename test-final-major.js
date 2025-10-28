// 최종 주요 종목 실시간 검색 테스트
async function testFinalMajorSearch(keyword) {
  try {
    console.log(`=== ${keyword} 최종 실시간 검색 테스트 ===`);
    
    // 주요 종목들의 실시간 검색 (간단한 매핑 사용)
    const majorStocks = [
      { code: '005930', name: '삼성전자', keywords: ['삼성전자', '삼성', 'samsung'] },
      { code: '000660', name: 'SK하이닉스', keywords: ['sk하이닉스', 'sk', '하이닉스'] },
      { code: '035420', name: 'NAVER', keywords: ['네이버', 'naver'] },
      { code: '035720', name: '카카오', keywords: ['카카오', 'kakao'] },
      { code: '005380', name: '현대차', keywords: ['현대차', '현대', 'hyundai'] },
      { code: '000270', name: '기아', keywords: ['기아', 'kia'] },
      { code: '051910', name: 'LG화학', keywords: ['lg화학', 'lg', '화학'] },
      { code: '068270', name: '셀트리온', keywords: ['셀트리온', 'celltrion'] },
      { code: '096350', name: '대창솔루션', keywords: ['대창솔루션', '대창'] },
      { code: '065450', name: '빅텍', keywords: ['빅텍', 'bigtech'] },
      { code: '086520', name: '에코프로', keywords: ['에코프로', 'ecopro'] },
      { code: '323410', name: '카카오뱅크', keywords: ['카카오뱅크', '카뱅'] },
      { code: '373220', name: 'LG에너지솔루션', keywords: ['lg에너지솔루션', 'lg에너지'] },
      { code: '207940', name: '삼성바이오로직스', keywords: ['삼성바이오로직스', '삼성바이오'] },
      { code: '006400', name: '삼성SDI', keywords: ['삼성sdi', 'sdi'] },
      { code: '017670', name: 'SK텔레콤', keywords: ['sk텔레콤', 'sk텔레콤'] },
      { code: '030200', name: 'KT', keywords: ['kt', '케이티'] },
      { code: '034730', name: 'SK', keywords: ['sk'] },
      { code: '003550', name: 'LG', keywords: ['lg'] },
      { code: '005490', name: 'POSCO홀딩스', keywords: ['포스코', 'posco'] },
      { code: '015760', name: '한국전력', keywords: ['한국전력', '한전'] },
      { code: '055550', name: '신한지주', keywords: ['신한지주', '신한'] },
      { code: '105560', name: 'KB금융', keywords: ['kb금융', 'kb'] },
      { code: '086790', name: '하나금융지주', keywords: ['하나금융지주', '하나'] },
      { code: '012330', name: '현대모비스', keywords: ['현대모비스', '모비스'] },
      { code: '086280', name: '현대글로비스', keywords: ['현대글로비스', '글로비스'] },
      { code: '000720', name: '현대건설', keywords: ['현대건설', '건설'] },
      { code: '267250', name: 'HD현대중공업', keywords: ['hd현대중공업', '현대중공업'] },
      { code: '004020', name: '현대제철', keywords: ['현대제철', '제철'] },
      { code: '066570', name: 'LG전자', keywords: ['lg전자', '전자'] },
      { code: '034220', name: 'LG디스플레이', keywords: ['lg디스플레이', '디스플레이'] },
      { code: '032640', name: 'LG유플러스', keywords: ['lg유플러스', '유플러스'] },
      { code: '051900', name: 'LG생활건강', keywords: ['lg생활건강', '생활건강'] },
      { code: '096770', name: 'SK이노베이션', keywords: ['sk이노베이션', '이노베이션'] },
      { code: '402340', name: 'SK스퀘어', keywords: ['sk스퀘어', '스퀘어'] },
      { code: '326030', name: 'SK바이오팜', keywords: ['sk바이오팜', '바이오팜'] },
      { code: '377300', name: '카카오페이', keywords: ['카카오페이', '페이'] },
      { code: '293490', name: '카카오게임즈', keywords: ['카카오게임즈', '게임즈'] },
      { code: '357780', name: '카카오모빌리티', keywords: ['카카오모빌리티', '모빌리티'] },
      { code: '091990', name: '셀트리온헬스케어', keywords: ['셀트리온헬스케어', '헬스케어'] },
      { code: '078930', name: 'GS', keywords: ['gs'] },
      { code: '009830', name: '한화솔루션', keywords: ['한화솔루션', '한화'] },
      { code: '034020', name: '두산에너빌리티', keywords: ['두산에너빌리티', '두산'] },
      { code: '042700', name: '한미반도체', keywords: ['한미반도체', '반도체'] },
      { code: '047050', name: '포스코인터내셔널', keywords: ['포스코인터내셔널', '인터내셔널'] },
      { code: '036460', name: '한국가스공사', keywords: ['한국가스공사', '가스공사'] },
      { code: '097950', name: 'CJ제일제당', keywords: ['cj제일제당', 'cj', '제일제당'] },
      { code: '247540', name: '에코프로비엠', keywords: ['에코프로비엠', '비엠'] },
      { code: '196170', name: '알테오젠', keywords: ['알테오젠'] },
      { code: '066970', name: '엘앤에프', keywords: ['엘앤에프', 'lnf'] },
      { code: '196300', name: '에이치엘비', keywords: ['에이치엘비', 'hlb'] },
      { code: '196490', name: '다이나믹디자인', keywords: ['다이나믹디자인', '다이나믹'] },
      { code: '196700', name: '웹젠', keywords: ['웹젠', 'webzen'] },
      { code: '196800', name: '아이에이', keywords: ['아이에이', 'ia'] },
      { code: '036200', name: '유니셈', keywords: ['유니셈', 'unisem'] }
    ];

    const results = [];
    const lowerKeyword = keyword.toLowerCase();
    
    console.log(`검색 키워드: ${keyword}`);
    console.log(`주요 종목 ${majorStocks.length}개 중에서 검색 중...`);
    
    for (const stock of majorStocks) {
      try {
        // 키워드 매칭 확인
        const isMatch = stock.keywords.some(kw => 
          kw.toLowerCase().includes(lowerKeyword) || lowerKeyword.includes(kw.toLowerCase())
        );
        
        if (isMatch) {
          console.log(`\n키워드 매칭: ${stock.name} (${stock.code})`);
          
          const priceInfo = await fetchStockPrice(stock.code);
          if (priceInfo) {
            results.push({
              symbol: stock.code,
              name: stock.name,
              market: stock.code.startsWith('0') ? 'KOSDAQ' : 'KOSPI',
              price: priceInfo.price,
              change: priceInfo.change || 0,
              changePercent: priceInfo.changePercent || 0,
              volume: priceInfo.volume || 0,
              marketCap: priceInfo.marketCap || 0,
              lastUpdate: new Date().toISOString(),
              source: 'naver-major-stocks',
              note: '실시간 크롤링 데이터'
            });
            
            console.log(`✅ 매칭된 종목: ${stock.name} (${stock.code}) - ${priceInfo.price.toLocaleString()}원`);
          } else {
            console.log(`❌ 가격 조회 실패: ${stock.name}`);
          }
        }
        
        // 요청 간격 조절
        await randomDelay(200, 500);
        
      } catch (error) {
        console.error(`종목 ${stock.code} 조회 오류:`, error);
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

function randomDelay(min, max) {
  const delay = Math.floor(Math.random() * (max - min + 1)) + min;
  return new Promise(resolve => setTimeout(resolve, delay));
}

// 테스트 실행
testFinalMajorSearch('삼성');
