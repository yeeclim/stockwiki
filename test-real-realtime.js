// 진짜 실시간 검색 테스트 (하드코딩 없음)
async function testRealRealtimeSearch(keyword) {
  try {
    console.log(`=== ${keyword} 진짜 실시간 검색 테스트 ===`);
    
    // 네이버 증권 검색 페이지에서 실시간 검색
    const searchUrl = `https://finance.naver.com/search/searchList.naver?query=${encodeURIComponent(keyword)}`;
    
    console.log(`검색 URL: ${searchUrl}`);
    
    const response = await fetch(searchUrl, {
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

    console.log(`응답 상태: ${response.status}`);
    
    if (!response.ok) {
      console.log(`검색 오류: ${response.status} ${response.statusText}`);
      return;
    }

    const html = await response.text();
    console.log(`HTML 길이: ${html.length}`);
    
    // 종목 정보 추출
    const stockResults = extractStockSearchResults(html, keyword);
    console.log(`추출된 종목: ${stockResults.length}개`);
    
    if (stockResults.length > 0) {
      console.log(`\n=== ${stockResults.length}개 종목 발견 ===`);
      stockResults.forEach((stock, index) => {
        console.log(`${index + 1}. ${stock.name} (${stock.symbol}) - ${stock.market}`);
      });
      
      // 첫 번째 종목의 가격 조회
      const firstStock = stockResults[0];
      console.log(`\n${firstStock.name} 가격 조회 중...`);
      
      const priceInfo = await fetchStockPrice(firstStock.symbol);
      if (priceInfo) {
        console.log(`\n=== ${firstStock.name} 주가 정보 ===`);
        console.log(`현재가: ${priceInfo.price.toLocaleString()}원`);
        console.log(`전일대비: ${priceInfo.change > 0 ? '+' : ''}${priceInfo.change.toLocaleString()}원`);
        console.log(`등락률: ${priceInfo.changePercent > 0 ? '+' : ''}${priceInfo.changePercent}%`);
        console.log(`조회시간: ${new Date().toLocaleString()}`);
      } else {
        console.log('가격 조회 실패');
      }
    } else {
      console.log('검색 결과 없음');
    }

  } catch (error) {
    console.error('검색 오류:', error);
  }
}

function extractStockSearchResults(html, keyword) {
  const results = [];
  
  console.log('HTML에서 종목 정보 추출 중...');
  
  // 네이버 증권 검색 결과에서 종목 정보 추출하는 다양한 패턴
  const patterns = [
    // 종목명과 코드가 함께 있는 패턴들
    /<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>/g,
    /<td[^>]*>[\s\S]*?<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/td>/g,
    /<tr[^>]*>[\s\S]*?<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/tr>/g,
    /<div[^>]*>[\s\S]*?<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/div>/g,
    /<span[^>]*>[\s\S]*?<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/span>/g,
    /<p[^>]*>[\s\S]*?<a[^>]*href="[^"]*item[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/p>/g,
    // 추가 패턴들
    /<a[^>]*href="[^"]*\/item\/main\.naver\?code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>/g,
    /<a[^>]*href="[^"]*\/item\/chart\.naver\?code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>/g,
    /<a[^>]*href="[^"]*\/item\/board\.naver\?code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>/g,
    // 테이블 내 패턴들
    /<td[^>]*class="[^"]*"[^>]*>[\s\S]*?<a[^>]*href="[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/td>/g,
    /<th[^>]*class="[^"]*"[^>]*>[\s\S]*?<a[^>]*href="[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/th>/g,
    // 리스트 패턴들
    /<li[^>]*>[\s\S]*?<a[^>]*href="[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/li>/g,
    /<ul[^>]*>[\s\S]*?<a[^>]*href="[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/ul>/g,
    // 일반적인 링크 패턴들
    /href="[^"]*code=(\d{6})[^"]*"[^>]*>([^<]+)</g
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) {
      const code = match[1];
      const name = match[2].trim();
      
      // 종목명이 키워드를 포함하는지 확인 (더 유연한 매칭)
      if (code && name && name.length > 0 && name.length < 50) {
        const lowerName = name.toLowerCase();
        const lowerKeyword = keyword.toLowerCase();
        
        // 키워드 매칭 확인 (부분 매칭)
        if (lowerName.includes(lowerKeyword) || lowerKeyword.includes(lowerName)) {
          results.push({
            symbol: code,
            name: name,
            market: code.startsWith('0') ? 'KOSDAQ' : 'KOSPI'
          });
          console.log(`추출된 종목: ${name} (${code})`);
        }
      }
    }
  }

  // 중복 제거
  const uniqueResults = results.filter((stock, index, self) => 
    index === self.findIndex(s => s.symbol === stock.symbol)
  );

  console.log(`중복 제거 후 ${uniqueResults.length}개 종목`);
  return uniqueResults;
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

// 테스트 실행
testRealRealtimeSearch('삼성');
