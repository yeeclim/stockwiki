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
        console.log(`🌐 실시간 실시간 가격 시도: ${stock['한글 종목명']} (${code})`);
        const realTimeData = await fetchStockData(code, stock['시장구분']);

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
            source: 'yahoo-finance',
            note: '실시간 API 데이터'
          };
        }
      } catch (error) {
        console.error(`❌ 실시간 API 실패: ${stock['한글 종목명']} (${code})`, error.message);
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

  // 검색 우선순위 정렬 루틴
  const sortedStocks = matchingStocks.sort((a, b) => {
    const aName = a['한글 종목명'] || '';
    const aShortName = a['한글 종목약명'] || '';
    const bName = b['한글 종목명'] || '';
    const bShortName = b['한글 종목약명'] || '';
    const aCode = a['단축코드'] || '';
    const bCode = b['단축코드'] || '';

    // 1위: 검색어와 완전히 일치하는 종목 최우선
    const aExact = aName === searchKeyword || aShortName === searchKeyword || aCode === searchKeyword;
    const bExact = bName === searchKeyword || bShortName === searchKeyword || bCode === searchKeyword;

    if (aExact && !bExact) return -1;
    if (!aExact && bExact) return 1;

    // 2위: 시장구분별 우선순위 (KOSPI > KOSDAQ)
    if (a['시장구분'] === 'KOSPI' && b['시장구분'] !== 'KOSPI') return -1;
    if (b['시장구분'] === 'KOSPI' && a['시장구분'] !== 'KOSPI') return 1;

    // 3위: 이름이 짧은 문자 순서대로 정렬 (불필요한 파생 상품 배제)
    if (aName.length !== bName.length) {
      return aName.length - bName.length;
    }

    return 0;
  });

  return sortedStocks.slice(0, limit);
}

// 추정 가격 계산 (가짜 데이터 제거)
function getEstimatedPrice(code, stock) {
  return 0; // 실시간 주가를 못 가져올 경우 임의의 추정치를 주지 않고 0을 반환
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

// Yahoo Finance API를 통한 실시간 가격 조회
async function fetchStockData(symbol, market) {
  try {
    const marketSuffix = market === 'KOSPI' ? '.KS' : '.KQ';
    const yahooSymbol = `${symbol}${marketSuffix}`;
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}?interval=1d&range=1d`;

    // node-fetch는 Vercel Edge나 Node 환경에서 글로벌 fetch로 대체되는 경우가 많음
    const fetchFn = globalThis.fetch || (await import('node-fetch')).default;

    const response = await fetchFn(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      timeout: 8000
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    const result = data?.chart?.result?.[0];

    if (result && result.meta && result.meta.regularMarketPrice > 0) {
      const price = result.meta.regularMarketPrice;
      const prevClose = result.meta.chartPreviousClose || price;
      const change = price - prevClose;
      const changePercent = prevClose > 0 ? (change / prevClose) * 100 : 0;
      const volume = result.meta.regularMarketVolume || 0;

      return {
        price,
        change,
        changePercent,
        volume,
        marketCap: 0
      };
    }

    return null;
  } catch (error) {
    console.error(`❌ ${symbol} API 오류:`, error.message);
    return null;
  }
}
