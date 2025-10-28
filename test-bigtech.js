// 빅텍 가격 조회 테스트
async function fetchStockPrice(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    // 랜덤 지연 (봇 탐지 회피)
    await randomDelay(1000, 2000);
    
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
      console.log(`HTTP 오류: ${response.status}`);
      return null;
    }

    const html = await response.text();
    console.log(`HTML 길이: ${html.length}`);
    
    // 가격 정보 추출
    const pricePatterns = [
      /<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/,
      /<span class="no_today"[^>]*>([^<]+)<\/span>/,
      /<em class="no_today"[^>]*>([^<]+)<\/em>/,
      /<strong class="no_today"[^>]*>([^<]+)<\/strong>/,
      /<span[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/span>/,
      /<em[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/em>/,
      /<strong[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/strong>/
    ];

    let price = null;
    for (const pattern of pricePatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const priceStr = match[1].replace(/,/g, '');
        const priceNum = parseInt(priceStr);
        if (priceNum && priceNum > 0 && priceNum < 10000000) {
          price = priceNum;
          console.log(`가격 패턴 매칭: ${match[1]} -> ${price}원`);
          break;
        }
      }
    }

    // 전일 대비 정보 추출
    let change = 0;
    let changePercent = 0;
    
    const changePatterns = [
      /<span[^>]*class="[^"]*no_exday[^"]*"[^>]*>([+-]?[\d,]+)<\/span>/,
      /<em[^>]*class="[^"]*no_exday[^"]*"[^>]*>([+-]?[\d,]+)<\/em>/,
      /<strong[^>]*class="[^"]*no_exday[^"]*"[^>]*>([+-]?[\d,]+)<\/strong>/
    ];

    for (const pattern of changePatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const changeStr = match[1].replace(/,/g, '');
        const changeNum = parseInt(changeStr);
        if (changeNum !== 0) {
          change = changeNum;
          console.log(`변동가 패턴 매칭: ${match[1]} -> ${change}원`);
          break;
        }
      }
    }

    // 등락률 추출
    const percentPatterns = [
      /<span[^>]*class="[^"]*no_exday[^"]*"[^>]*>[\s\S]*?([+-]?[\d.]+%)/,
      /<em[^>]*class="[^"]*no_exday[^"]*"[^>]*>[\s\S]*?([+-]?[\d.]+%)/,
      /<strong[^>]*class="[^"]*no_exday[^"]*"[^>]*>[\s\S]*?([+-]?[\d.]+%)/
    ];

    for (const pattern of percentPatterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const percentStr = match[1].replace('%', '');
        const percentNum = parseFloat(percentStr);
        if (percentNum !== 0) {
          changePercent = percentNum;
          console.log(`등락률 패턴 매칭: ${match[1]} -> ${changePercent}%`);
          break;
        }
      }
    }

    if (price) {
      return {
        price: price,
        change: change,
        changePercent: changePercent,
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

// 빅텍 가격 조회
console.log('빅텍(065450) 가격 조회 중...');
fetchStockPrice('065450').then(result => {
  if (result) {
    console.log('\n=== 빅텍 주가 정보 ===');
    console.log(`현재가: ${result.price.toLocaleString()}원`);
    console.log(`전일대비: ${result.change > 0 ? '+' : ''}${result.change.toLocaleString()}원`);
    console.log(`등락률: ${result.changePercent > 0 ? '+' : ''}${result.changePercent}%`);
    console.log(`조회시간: ${new Date().toLocaleString()}`);
  } else {
    console.log('빅텍 가격 조회 실패');
  }
});
