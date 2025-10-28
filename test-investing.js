// Investing.com 실시간 검색 테스트
async function testInvestingSearch(keyword) {
  try {
    console.log(`=== ${keyword} Investing.com 실시간 검색 테스트 ===`);
    
    // Investing.com에서 한국 주식 검색
    const searchUrl = `https://www.investing.com/search/?q=${encodeURIComponent(keyword)}&tab=quotes`;
    
    console.log(`검색 URL: ${searchUrl}`);
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://www.investing.com/',
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
    const stockResults = extractInvestingStockResults(html, keyword);
    console.log(`추출된 한국 주식: ${stockResults.length}개`);
    
    if (stockResults.length > 0) {
      console.log(`\n=== ${stockResults.length}개 한국 주식 발견 ===`);
      stockResults.forEach((stock, index) => {
        console.log(`${index + 1}. ${stock.name} (${stock.symbol}) - ${stock.market}`);
      });
      
      // 첫 번째 종목의 가격 조회
      const firstStock = stockResults[0];
      console.log(`\n${firstStock.name} 가격 조회 중...`);
      
      const priceInfo = await fetchInvestingStockPrice(firstStock.symbol);
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

function extractInvestingStockResults(html, keyword) {
  const results = [];
  
  console.log('Investing.com HTML에서 한국 주식 정보 추출 중...');
  
  // Investing.com 검색 결과에서 한국 주식 정보 추출하는 패턴들
  const patterns = [
    // 한국 주식 링크 패턴들
    /<a[^>]*href="[^"]*\/equities\/([^"]*)"[^>]*>([^<]+)<\/a>/g,
    /<a[^>]*href="[^"]*\/stocks\/([^"]*)"[^>]*>([^<]+)<\/a>/g,
    /<a[^>]*href="[^"]*\/quotes\/([^"]*)"[^>]*>([^<]+)<\/a>/g,
    // 테이블 내 패턴들
    /<td[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/equities\/([^"]*)"[^>]*>([^<]+)<\/a>[\s\S]*?<\/td>/g,
    /<tr[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/equities\/([^"]*)"[^>]*>([^<]+)<\/a>[\s\S]*?<\/tr>/g,
    // 리스트 패턴들
    /<li[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/equities\/([^"]*)"[^>]*>([^<]+)<\/a>[\s\S]*?<\/li>/g,
    /<div[^>]*>[\s\S]*?<a[^>]*href="[^"]*\/equities\/([^"]*)"[^>]*>([^<]+)<\/a>[\s\S]*?<\/div>/g
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) {
      const symbol = match[1];
      const name = match[2].trim();
      
      // 한국 주식인지 확인 (KOSPI/KOSDAQ)
      if (symbol && name && name.length > 0 && name.length < 100) {
        const lowerName = name.toLowerCase();
        const lowerKeyword = keyword.toLowerCase();
        
        // 키워드 매칭 확인
        if (lowerName.includes(lowerKeyword) || lowerKeyword.includes(lowerName)) {
          // 한국 주식인지 확인 (KOSPI/KOSDAQ 포함)
          if (symbol.includes('kospi') || symbol.includes('kosdaq') || 
              name.includes('KOSPI') || name.includes('KOSDAQ') ||
              symbol.match(/\d{6}/)) {
            results.push({
              symbol: symbol,
              name: name,
              market: symbol.includes('kosdaq') ? 'KOSDAQ' : 'KOSPI'
            });
            console.log(`추출된 한국 주식: ${name} (${symbol})`);
          }
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

async function fetchInvestingStockPrice(symbol) {
  try {
    console.log(`Investing.com에서 ${symbol} 가격 조회 중...`);
    
    // Investing.com 주식 페이지 URL
    const url = `https://www.investing.com/equities/${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://www.investing.com/',
        'DNT': '1'
      }
    });

    if (!response.ok) {
      console.log(`Investing.com 가격 조회 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    
    // 가격 정보 추출
    const pricePatterns = [
      /<span class="text-2xl[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span class="text-3xl[^"]*"[^>]*>([^<]+)<\/span>/,
      /<span class="text-4xl[^"]*"[^>]*>([^<]+)<\/span>/,
      /<div class="text-2xl[^"]*"[^>]*>([^<]+)<\/div>/,
      /<div class="text-3xl[^"]*"[^>]*>([^<]+)<\/div>/,
      /<span[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/span>/,
      /<div[^>]*class="[^"]*price[^"]*"[^>]*>([^<]+)<\/div>/,
      /<span[^>]*data-test="instrument-price-last"[^>]*>([^<]+)<\/span>/,
      /<div[^>]*data-test="instrument-price-last"[^>]*>([^<]+)<\/div>/
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
      console.log(`Investing.com 가격 조회 성공: ${price}`);
      return {
        price: price,
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: 0
      };
    }

    console.log(`Investing.com 가격 조회 실패: ${symbol}`);
    return null;

  } catch (error) {
    console.error(`Investing.com 가격 조회 오류:`, error);
    return null;
  }
}

// 테스트 실행
testInvestingSearch('samsung');
