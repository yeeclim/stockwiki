// 진짜 실시간 검색 테스트
async function testRealtimeSearch(keyword) {
  try {
    console.log(`=== ${keyword} 실시간 검색 테스트 ===`);
    
    // 네이버 모바일 API 테스트
    const searchUrl = `https://m.stock.naver.com/api/search/stock?query=${encodeURIComponent(keyword)}&pageSize=5`;
    
    console.log(`검색 URL: ${searchUrl}`);
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Referer': 'https://m.stock.naver.com/',
        'DNT': '1'
      }
    });

    console.log(`응답 상태: ${response.status}`);
    
    if (!response.ok) {
      console.log(`API 오류: ${response.status} ${response.statusText}`);
      return;
    }

    const data = await response.json();
    console.log(`검색 결과:`, JSON.stringify(data, null, 2));
    
    if (data && data.stocks && data.stocks.length > 0) {
      console.log(`\n=== ${data.stocks.length}개 종목 발견 ===`);
      data.stocks.forEach((stock, index) => {
        console.log(`${index + 1}. ${stock.name} (${stock.code}) - ${stock.market || 'KOSPI'}`);
      });
    } else {
      console.log('검색 결과 없음');
    }

  } catch (error) {
    console.error('검색 오류:', error);
  }
}

// 여러 종목 테스트
const testKeywords = ['삼성전자', '카카오', '빅텍', '대창솔루션', '네이버'];

async function runTests() {
  for (const keyword of testKeywords) {
    await testRealtimeSearch(keyword);
    console.log('\n' + '='.repeat(50) + '\n');
    await new Promise(resolve => setTimeout(resolve, 2000)); // 2초 대기
  }
}

runTests();
