// import fetch from 'node-fetch'; // Vercel에서는 내장 fetch 사용
import fs from 'fs';
import path from 'path';

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
    console.log(`🔍 전체 종목 검색: ${keyword}`);
    
    // 1단계: KRX 전체 데이터에서 검색
    const allStocks = await loadKRXData();
    const matchingStocks = searchInKRXData(allStocks, keyword, limit);
    
    if (matchingStocks.length === 0) {
      return res.status(404).json({
        success: false,
        error: '검색 결과가 없습니다'
      });
    }

    console.log(`✅ KRX 검색 결과: ${matchingStocks.length}개`);

    // 2단계: 실시간 가격 업데이트 시도 (모든 결과 대상, 실패 시 폴백)
    const results = await Promise.all(matchingStocks.map(async (stock) => {
      const code = stock['단축코드'];
      try {
        console.log(`🌐 실시간 크롤링 시도: ${stock['한글 종목명']} (${code})`);
        const realTimeData = await fetchStockData(code);
        
        if (realTimeData && realTimeData.price > 0) {
          return {
            symbol: code,
            name: stock['한글 종목명'],
            shortName: stock['한글 종목약명'],
            market: stock['시장구분'],
            price: realTimeData.price,
            change: realTimeData.change,
            changePercent: realTimeData.changePercent,
            volume: realTimeData.volume,
            marketCap: realTimeData.marketCap,
            lastUpdate: new Date().toISOString(),
            source: 'naver-finance',
            note: '실시간 크롤링 데이터'
          };
        }
      } catch (error) {
        console.error(`❌ 실시간 크롤링 실패: ${stock['한글 종목명']} (${code})`, error.message);
      }
      
      // 실시간 데이터 실패 시 추정 가격 제공
      const estimatedPrice = getEstimatedPrice(code, stock);
      return {
        symbol: code,
        name: stock['한글 종목명'],
        shortName: stock['한글 종목약명'],
        market: stock['시장구분'],
        price: estimatedPrice,
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: stock['상장주식수'] || 0,
        lastUpdate: new Date().toISOString(),
        source: 'estimated-price',
        note: '추정 가격 (실시간 업데이트 필요)'
      };
    }));

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

// KRX 데이터 로드 (캐싱 적용)
let krxDataCache = null;
let krxDataCacheTime = null;
const CACHE_DURATION = 60 * 60 * 1000; // 1시간

async function loadKRXData() {
  const now = Date.now();
  
  // 캐시 확인
  if (krxDataCache && krxDataCacheTime && (now - krxDataCacheTime) < CACHE_DURATION) {
    console.log('📦 KRX 데이터 캐시 사용');
    return krxDataCache;
  }

  try {
    console.log('📁 KRX 데이터 로드 중...');
    // 여러 경로 시도
    const possiblePaths = [
      path.join(process.cwd(), 'assets', 'krx_basic_info.json'),
      path.join(process.cwd(), 'assets', 'data', 'krx_basic_info.json'),
      path.join(process.cwd(), 'web', 'assets', 'krx_basic_info.json'),
    ];
    
    let fileContent = null;
    let filePath = null;
    
    for (const tryPath of possiblePaths) {
      try {
        if (fs.existsSync(tryPath)) {
          filePath = tryPath;
          fileContent = fs.readFileSync(tryPath, 'utf8');
          console.log(`✅ KRX 데이터 파일 찾음: ${tryPath}`);
          break;
        }
      } catch (e) {
        // 다음 경로 시도
        continue;
      }
    }
    
    if (!fileContent) {
      throw new Error(`KRX 데이터 파일을 찾을 수 없습니다. 시도한 경로: ${possiblePaths.join(', ')}`);
    }
    
    const data = JSON.parse(fileContent);
    
    // 캐시 저장
    krxDataCache = data;
    krxDataCacheTime = now;
    
    console.log(`✅ KRX 데이터 로드 완료: ${data.length}개 종목`);
    return data;
  } catch (error) {
    console.error('❌ KRX 데이터 로드 실패:', error);
    return [];
  }
}

// KRX 데이터에서 검색
function searchInKRXData(allStocks, keyword, limit) {
  // 한글 검색을 위해 toLowerCase() 제거 (한글은 대소문자가 없음)
  const searchKeyword = keyword.trim();
  
  console.log(`🔍 검색 키워드: "${searchKeyword}"`);
  console.log(`📊 전체 종목 수: ${allStocks.length}`);
  
  const matchingStocks = allStocks.filter(stock => {
    const name = stock['한글 종목명'] || '';
    const shortName = stock['한글 종목약명'] || '';
    const code = stock['단축코드'] || '';
    
    // 정확한 매칭 우선, 부분 매칭도 허용
    const nameMatch = name.includes(searchKeyword) || name === searchKeyword;
    const shortNameMatch = shortName.includes(searchKeyword) || shortName === searchKeyword;
    const codeMatch = code.includes(searchKeyword) || code === searchKeyword;
    
    return nameMatch || shortNameMatch || codeMatch;
  });

  console.log(`✅ 매칭된 종목 수: ${matchingStocks.length}개`);
  if (matchingStocks.length > 0) {
    console.log(`📋 첫 번째 결과: ${matchingStocks[0]['한글 종목명']} (${matchingStocks[0]['단축코드']})`);
  }

  // 시장구분별 우선순위 (KOSPI > KOSDAQ)
  const sortedStocks = matchingStocks.sort((a, b) => {
    if (a['시장구분'] === 'KOSPI' && b['시장구분'] !== 'KOSPI') return -1;
    if (b['시장구분'] === 'KOSPI' && a['시장구분'] !== 'KOSPI') return 1;
    return 0;
  });

  return sortedStocks.slice(0, limit);
}

// 추정 가격 계산
function getEstimatedPrice(code, stock) {
  const stockName = stock['한글 종목명'] || '';
  const marketCap = stock['상장주식수'] || 0;
  const market = stock['시장구분'] || '';
  
  // 알려진 가격 데이터 (2025년 10월 기준)
  const knownPrices = {
    // 대형주
    '005930': 95000,  // 삼성전자
    '000660': 120000, // SK하이닉스
    '035420': 180000, // NAVER
    '035720': 45000,  // 카카오
    '207940': 1127000, // 삼성바이오로직스
    '006400': 221500, // 삼성SDI
    '051910': 350000, // LG화학
    '068270': 180000, // 셀트리온
    '005490': 350000, // POSCO홀딩스
    '017670': 50000,  // SK텔레콤
    '105560': 55000,  // KB금융
    '055550': 40000,  // 신한지주
    '096770': 120000, // SK이노베이션
    '066570': 100000, // LG전자
    '003550': 85000,  // LG
    '018260': 150000, // 삼성에스디에스
    '015760': 20000,  // 한국전력
    '012330': 250000, // 현대모비스
    '000810': 280000, // 삼성화재
    '086280': 180000, // 현대글로비스
    '028260': 120000, // 삼성물산
    '032830': 80000,  // 삼성생명
    '003670': 400000, // 포스코홀딩스
    '024110': 12000,  // 기업은행
    '030200': 35000,  // KT
    '011200': 15000,  // HMM
    '086790': 45000,  // 하나금융지주
    '377300': 50000,  // 카카오페이
    '161890': 50000,  // 한국항공우주
    '034730': 60000,  // SK
    '003490': 25000,  // 대한항공
    '259960': 150000, // 크래프톤
    '035900': 80000,  // JYP Ent.
    '251270': 60000,  // 넷마블
    '091990': 150000, // 셀트리온헬스케어
    '078930': 40000,  // GS
    '000720': 35000,  // 현대건설
    '267250': 80000,  // HD현대중공업
    '042700': 120000, // 한미반도체
    '047050': 45000,  // 포스코인터내셔널
    
    // 기타 주요 종목
    '323410': 45000,  // 카카오뱅크
    '000270': 100000, // 기아
    '005380': 200000, // 현대차
    '090430': 120000, // 아모레퍼시픽
    '090435': 100000, // 아모레퍼시픽우
    '002795': 80000,  // 아모레퍼시픽홀딩스우
    '001040': 80000,  // CJ
    '001045': 75000,  // CJ우
    '00104K': 70000,  // CJ4우
  };
  
  // 알려진 가격이 있으면 반환
  if (knownPrices[code]) {
    return knownPrices[code];
  }
  
  // 시가총액 기반 추정 가격
  if (marketCap > 0) {
    if (marketCap > 100000000000) { // 1000억 이상 (대형주)
      return Math.floor(marketCap / 1000000000); // 대략적인 주가
    } else if (marketCap > 10000000000) { // 100억 이상 (중형주)
      return Math.floor(marketCap / 100000000) * 10;
    } else { // 소형주
      return Math.floor(marketCap / 10000000) * 100;
    }
  }
  
  // 종목명 기반 추정
  if (stockName.includes('금융') || stockName.includes('은행')) {
    return 50000; // 금융주 평균
  } else if (stockName.includes('화학') || stockName.includes('석유')) {
    return 150000; // 화학주 평균
  } else if (stockName.includes('전자') || stockName.includes('반도체')) {
    return 80000; // 전자주 평균
  } else if (stockName.includes('바이오') || stockName.includes('제약')) {
    return 200000; // 바이오주 평균
  } else if (stockName.includes('게임') || stockName.includes('엔터')) {
    return 100000; // 게임/엔터 평균
  } else if (stockName.includes('건설') || stockName.includes('부동산')) {
    return 30000; // 건설/부동산 평균
  }
  
  // 기본 추정 가격
  return market === 'KOSPI' ? 50000 : 30000; // KOSPI 5만원, KOSDAQ 3만원
}

// 주요 종목 판별 (실시간 크롤링 대상)
function isMajorStock(code) {
  const majorCodes = [
    '005930', // 삼성전자
    '000660', // SK하이닉스  
    '035420', // NAVER
    '035720', // 카카오
    '207940', // 삼성바이오로직스
    '006400', // 삼성SDI
    '051910', // LG화학
    '068270', // 셀트리온
    '005490', // POSCO홀딩스
    '017670', // SK텔레콤
    '105560', // KB금융
    '055550', // 신한지주
    '096770', // SK이노베이션
    '066570', // LG전자
    '003550', // LG
    '018260', // 삼성에스디에스
    '015760', // 한국전력
    '012330', // 현대모비스
    '000810', // 삼성화재
    '086280', // 현대글로비스
    '028260', // 삼성물산
    '032830', // 삼성생명
    '003670', // 포스코홀딩스
    '024110', // 기업은행
    '030200', // KT
    '011200', // HMM
    '086790', // 하나금융지주
    '377300', // 카카오페이
    '161890', // 한국항공우주
    '034730', // SK
    '003490', // 대한항공
    '259960', // 크래프톤
    '035900', // JYP Ent.
    '251270', // 넷마블
    '091990', // 셀트리온헬스케어
    '078930', // GS
    '000720', // 현대건설
    '267250', // HD현대중공업
    '042700', // 한미반도체
    '047050', // 포스코인터내셔널
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
      timeout: 8000
    });

    if (!response.ok) {
      return null;
    }

    const html = await response.text();
    
    if (html.trim().startsWith('<!DOCTYPE') || html.trim().startsWith('<html')) {
      const priceInfo = extractPriceInfo(html);
      if (priceInfo.price > 0) {
        return {
          price: priceInfo.price,
          change: priceInfo.change,
          changePercent: priceInfo.changePercent,
          volume: priceInfo.volume,
          marketCap: priceInfo.marketCap
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
    const priceMatch = html.match(/<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/);
    const price = priceMatch ? parseInt(priceMatch[1].replace(/,/g, '')) : 0;
    
    const changeMatch = html.match(/<span class="tah[^"]*"[^>]*>([+-]?\d+\.?\d*)%?<\/span>/);
    const changePercent = changeMatch ? parseFloat(changeMatch[1]) : 0;
    
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
