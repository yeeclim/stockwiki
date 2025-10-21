// import fetch from 'node-fetch'; // Vercel에서는 내장 fetch 사용

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

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
    console.log(`🚀 빠른 종목 검색: ${keyword}`);
    
    // 1단계: 기본 데이터로 빠른 응답
    const basicResults = getBasicStockData(keyword, limit);
    
    if (basicResults.length === 0) {
      return res.status(404).json({
        success: false,
        error: '검색 결과가 없습니다'
      });
    }

    // 2단계: 주요 종목에 대해서만 실시간 데이터 병렬 가져오기 (비동기)
    const realTimePromises = basicResults.map(async (stock) => {
      // 주요 종목만 실시간 크롤링 (성능 최적화)
      if (isMajorStock(stock.code)) {
        try {
          console.log(`🌐 실시간 크롤링: ${stock.name} (${stock.code})`);
          const realTimeData = await fetchStockData(stock.code);
          
          if (realTimeData && realTimeData.price > 0) {
            console.log(`✅ 실시간 데이터 성공: ${stock.name} - ${realTimeData.price}원`);
            return { ...stock, ...realTimeData };
          }
        } catch (error) {
          console.error(`❌ 실시간 크롤링 실패: ${stock.name}`, error.message);
        }
      }
      
      // 실시간 데이터 실패 시 기본 데이터 반환
      return {
        ...stock,
        lastUpdate: new Date().toISOString(),
        source: 'basic-data',
        note: '기본 데이터'
      };
    });

    const results = await Promise.all(realTimePromises);
    console.log(`🎯 최종 결과: ${results.length}개 종목`);
    
    return res.status(200).json({
      success: true,
      keyword: keyword,
      count: results.length,
      data: results,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ 종목 검색 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다',
      details: error.message
    });
  }
}

// 기본 종목 데이터 (빠른 검색용) - 더 많은 종목 포함
function getBasicStockData(keyword, limit) {
  const allStocks = [
    // 주요 대형주 (2025년 10월 기준 추정 가격)
    { code: '005930', name: '삼성전자', price: 80000, change: 0, changePercent: 0 },
    { code: '000660', name: 'SK하이닉스', price: 120000, change: 0, changePercent: 0 },
    { code: '035420', name: 'NAVER', price: 180000, change: 0, changePercent: 0 },
    { code: '035720', name: '카카오', price: 45000, change: 0, changePercent: 0 },
    { code: '207940', name: '삼성바이오로직스', price: 800000, change: 0, changePercent: 0 },
    { code: '006400', name: '삼성SDI', price: 400000, change: 0, changePercent: 0 },
    { code: '051910', name: 'LG화학', price: 350000, change: 0, changePercent: 0 },
    { code: '068270', name: '셀트리온', price: 180000, change: 0, changePercent: 0 },
    { code: '323410', name: '카카오뱅크', price: 45000, change: 0, changePercent: 0 },
    { code: '000270', name: '기아', price: 100000, change: 0, changePercent: 0 },
    
    // 금융주
    { code: '105560', name: 'KB금융', price: 55000, change: 0, changePercent: 0 },
    { code: '055550', name: '신한지주', price: 40000, change: 0, changePercent: 0 },
    { code: '086790', name: '하나금융지주', price: 45000, change: 0, changePercent: 0 },
    { code: '024110', name: '기업은행', price: 12000, change: 0, changePercent: 0 },
    { code: '071050', name: '한국금융지주', price: 60000, change: 0, changePercent: 0 },
    
    // 통신주
    { code: '017670', name: 'SK텔레콤', price: 50000, change: 0, changePercent: 0 },
    { code: '030200', name: 'KT', price: 35000, change: 0, changePercent: 0 },
    { code: '034730', name: 'SK', price: 60000, change: 0, changePercent: 0 },
    
    // 철강/화학
    { code: '005490', name: 'POSCO홀딩스', price: 350000, change: 0, changePercent: 0 },
    { code: '096770', name: 'SK이노베이션', price: 120000, change: 0, changePercent: 0 },
    { code: '003670', name: '포스코홀딩스', price: 400000, change: 0, changePercent: 0 },
    { code: '078930', name: 'GS', price: 40000, change: 0, changePercent: 0 },
    { code: '047050', name: '포스코인터내셔널', price: 45000, change: 0, changePercent: 0 },
    
    // 전자/기술
    { code: '066570', name: 'LG전자', price: 100000, change: 0, changePercent: 0 },
    { code: '003550', name: 'LG', price: 85000, change: 0, changePercent: 0 },
    { code: '018260', name: '삼성에스디에스', price: 150000, change: 0, changePercent: 0 },
    { code: '042700', name: '한미반도체', price: 120000, change: 0, changePercent: 0 },
    { code: '377300', name: '카카오페이', price: 50000, change: 0, changePercent: 0 },
    
    // 자동차/부품
    { code: '012330', name: '현대모비스', price: 250000, change: 0, changePercent: 0 },
    { code: '086280', name: '현대글로비스', price: 180000, change: 0, changePercent: 0 },
    { code: '267250', name: 'HD현대중공업', price: 80000, change: 0, changePercent: 0 },
    
    // 보험/금융서비스
    { code: '000810', name: '삼성화재', price: 280000, change: 0, changePercent: 0 },
    { code: '032830', name: '삼성생명', price: 80000, change: 0, changePercent: 0 },
    { code: '028260', name: '삼성물산', price: 120000, change: 0, changePercent: 0 },
    
    // 유틸리티/인프라
    { code: '015760', name: '한국전력', price: 20000, change: 0, changePercent: 0 },
    { code: '000720', name: '현대건설', price: 35000, change: 0, changePercent: 0 },
    { code: '161890', name: '한국항공우주', price: 50000, change: 0, changePercent: 0 },
    
    // 운송/물류
    { code: '011200', name: 'HMM', price: 15000, change: 0, changePercent: 0 },
    { code: '003490', name: '대한항공', price: 25000, change: 0, changePercent: 0 },
    
    // 게임/엔터테인먼트
    { code: '259960', name: '크래프톤', price: 150000, change: 0, changePercent: 0 },
    { code: '035900', name: 'JYP Ent.', price: 80000, change: 0, changePercent: 0 },
    { code: '251270', name: '넷마블', price: 60000, change: 0, changePercent: 0 },
    
    // 바이오/제약
    { code: '091990', name: '셀트리온헬스케어', price: 150000, change: 0, changePercent: 0 },
    { code: '128940', name: '한미약품', price: 200000, change: 0, changePercent: 0 },
    { code: '185750', name: '종근당', price: 80000, change: 0, changePercent: 0 },
    
    // 소비재/식품
    { code: '000270', name: '기아', price: 100000, change: 0, changePercent: 0 },
    { code: '005380', name: '현대차', price: 200000, change: 0, changePercent: 0 },
    { code: '017940', name: 'E1', price: 70000, change: 0, changePercent: 0 },
  ];

  const lowerKeyword = keyword.toLowerCase();
  const matchingStocks = allStocks.filter(stock => 
    stock.name.toLowerCase().includes(lowerKeyword) ||
    stock.code.includes(lowerKeyword)
  );

  return matchingStocks.slice(0, limit);
}

// 주요 종목 판별 (실시간 크롤링 대상) - 상위 8개만
function isMajorStock(code) {
  const majorCodes = [
    '005930', // 삼성전자
    '000660', // SK하이닉스  
    '035420', // NAVER
    '035720', // 카카오
    '207940', // 삼성바이오로직스
    '006400', // 삼성SDI
    '051910', // LG화학
    '068270'  // 셀트리온
  ];
  return majorCodes.includes(code);
}

// 네이버 증권에서 실시간 데이터 크롤링
async function fetchStockData(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
      timeout: 8000 // 8초 타임아웃
    });

    if (!response.ok) {
      return null;
    }

    const html = await response.text();
    
    // HTML 응답이 JSON이 아닌 경우 체크
    if (html.trim().startsWith('<!DOCTYPE') || html.trim().startsWith('<html')) {
      const priceInfo = extractPriceInfo(html);
      if (priceInfo.price > 0) {
        return {
          symbol: symbol,
          price: priceInfo.price,
          change: priceInfo.change,
          changePercent: priceInfo.changePercent,
          volume: priceInfo.volume,
          marketCap: priceInfo.marketCap,
          lastUpdate: new Date().toISOString(),
          source: 'naver-finance',
          note: '실시간 크롤링 데이터'
        };
      }
    }
    
    return null;
  } catch (error) {
    console.error(`❌ ${symbol} 크롤링 오류:`, error.message);
    return null;
  }
}

// 가격 정보 추출
function extractPriceInfo(html) {
  try {
    // 현재가 추출
    const priceMatch = html.match(/<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    const price = priceMatch ? parseInt(priceMatch[1].replace(/,/g, '')) : 0;
    
    // 등락률 추출
    const changeMatch = html.match(/<span class="tah[^"]*"[^>]*>([+-]?\d+\.?\d*)%?<\/span>/);
    const changePercent = changeMatch ? parseFloat(changeMatch[1]) : 0;
    
    // 거래량 추출
    const volumeMatch = html.match(/<span class="tah[^"]*"[^>]*>([\d,]+)<\/span>/);
    const volume = volumeMatch ? parseInt(volumeMatch[1].replace(/,/g, '')) : 0;
    
    return {
      price: price,
      change: Math.round(price * changePercent / 100),
      changePercent: changePercent,
      volume: volume,
      marketCap: 0
    };
  } catch (error) {
    console.error('가격 정보 추출 오류:', error);
    return { price: 0, change: 0, changePercent: 0, volume: 0, marketCap: 0 };
  }
}
