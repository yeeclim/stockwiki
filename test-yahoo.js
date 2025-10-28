// Yahoo Finance 실시간 검색 테스트
async function testYahooSearch(keyword) {
  try {
    console.log(`=== ${keyword} Yahoo Finance 실시간 검색 테스트 ===`);
    
    // Yahoo Finance에서 한국 주식 검색
    const searchUrl = `https://finance.yahoo.com/lookup?s=${encodeURIComponent(keyword)}&t=A&b=0&c=100`;
    
    console.log(`검색 URL: ${searchUrl}`);
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://finance.yahoo.com/',
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
    const stockResults = extractYahooStockResults(html, keyword);
    console.log(`추출된 한국 주식: ${stockResults.length}개`);
    
    if (stockResults.length > 0) {
      console.log(`\n=== ${stockResults.length}개 한국 주식 발견 ===`);
      stockResults.forEach((stock, index) => {
        console.log(`${index + 1}. ${stock.name} (${stock.symbol}) - ${stock.market}`);
      });
      
      // 첫 번째 종목의 가격 조회
      const firstStock = stockResults[0];
      console.log(`\n${firstStock.name} 가격 조회 중...`);
      
      const priceInfo = await fetchYahooStockPrice(firstStock.symbol);
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

function extractYahooStockResults(html, keyword) {
  const results = [];
  
  console.log('Yahoo Finance HTML에서 한국 주식 정보 추출 중...');
  
  // Yahoo Finance 검색 결과에서 한국 주식 정보 추출하는 패턴들
  const patterns = [
    // 한국 주식 링크 패턴들 (.KS, .KQ)
    /<a[^>]*href="[^"]*\/quote\/([^"]*\.KS)[^"]*"[^>]*>([^<]+)<\/a>/g,
    /<a[^>]*href="[^"]*\/quote\/([^"]*\.KQ)[^"]*"[^>]*>([^<]+)<\/a>/g,
    // 테이블 내 패턴들
    /<td[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/quote\/([^"]*\.KS)[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/td>/g,
    /<td[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/quote\/([^"]*\.KQ)[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/td>/g,
    // 리스트 패턴들
    /<li[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/quote\/([^"]*\.KS)[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/li>/g,
    /<li[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/quote\/([^"]*\.KQ)[^"]*"[^>]*>([^<]+)<\/a>[\s\S]*?<\/li>/g,
    // 일반적인 링크 패턴들
    /href="[^"]*\/quote\/([^"]*\.KS)[^"]*"[^>]*>([^<]+)</g,
    /href="[^"]*\/quote\/([^"]*\.KQ)[^"]*"[^>]*>([^<]+)</g
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) {
      const symbol = match[1];
      const name = match[2].trim();
      
      // 한국 주식인지 확인 (.KS, .KQ)
      if (symbol && name && name.length > 0 && name.length < 100) {
        const lowerName = name.toLowerCase();
        const lowerKeyword = keyword.toLowerCase();
        
        // 키워드 매칭 확인
        if (lowerName.includes(lowerKeyword) || lowerKeyword.includes(lowerName)) {
          results.push({
            symbol: symbol,
            name: name,
            market: symbol.includes('.KQ') ? 'KOSDAQ' : 'KOSPI'
          });
          console.log(`추출된 한국 주식: ${name} (${symbol})`);
        }
      }
    }
  }

  // 중복 제거
  const uniqueResults = results.filter((stock, index, self) => 
    index === self.findIndex(s => s.symbol === stock.symbol)
  );

  console.log(`중복 제거 후 ${uniqueResults.length}개 한국 주식`);
  return uniqueResults;
}

async function fetchYahooStockPrice(symbol) {
  try {
    console.log(`Yahoo Finance에서 ${symbol} 가격 조회 중...`);
    
    // Yahoo Finance 주식 페이지 URL
    const url = `https://finance.yahoo.com/quote/${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://finance.yahoo.com/',
        'DNT': '1'
      }
    });

    if (!response.ok) {
      console.log(`Yahoo Finance 가격 조회 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 가격 정보 추출
    const pricePatterns = [
      /<span class="Trsdu\(0\.3s\)[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span class="Fw\(b\)[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span class="Fz\(36px\)[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span class="Fz\(32px\)[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span[^>]*data-test="qsp-price"[^>]*>([^<]+)<\/span>/,
      /<div[^>]*data-test="qsp-price"[^>]*>([^<]+)<\/div>/,
      /<span[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/span>/,
      /<div[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/div>/
    ];

    let price = null;
    for (const pattern of pricePatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const priceStr = match[1].replace(/,/g, '').replace(/[^\d.-]/g, '');
        const priceNum = parseFloat(priceStr);
        if (priceNum && priceNum > 0 && priceNum < 10000000) {
          price = Math.round(priceNum);
          break;
        }
      }
    }

    if (price) {
      console.log(`Yahoo Finance 가격 조회 성공: ${price}`);
      return {
        price: price,
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: 0
      };
    }

    console.log(`Yahoo Finance 가격 조회 실패: ${symbol}`);
    return null;

  } catch (error) {
    console.error(`Yahoo Finance 가격 조회 오류:`, error);
    return null;
  }
}

// 테스트 실행
testYahooSearch('samsung');
