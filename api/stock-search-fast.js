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
    console.log(`🚀 빠른 종목 검색: ${keyword}`);

    // 1단계: KRX 기본 데이터에서 검색
    const allStocks = await loadKRXData();
    const matchingStocks = searchInKRXData(allStocks, keyword, limit);

    if (matchingStocks.length === 0) {
      return res.status(404).json({
        success: false,
        error: '검색 결과가 없습니다'
      });
    }

    // 2단계: 빠른 응답을 위해 3개 종목만 실시간 데이터 가져오기 (비동기)
    const realTimePromises = matchingStocks.map(async (stock, index) => {
      // 상위 3개 종목만 실시간 크롤링 (성능 최적화)
      if (index < 3) {
        try {
          const code = stock['단축코드'];
          console.log(`🌐 실시간 크롤링: ${stock['한글 종목명']} (${code})`);
          const realTimeData = await fetchStockData(code);

          if (realTimeData && realTimeData.price > 0) {
            console.log(`✅ 실시간 데이터 성공: ${stock['한글 종목명']} - ${realTimeData.price}원`);
            return {
              symbol: code,
              name: stock['한글 종목명'],
              shortName: stock['한글 종목약명'],
              ...realTimeData
            };
          }
        } catch (error) {
          console.error(`❌ 실시간 크롤링 실패: ${stock['한글 종목명']}`, error.message);
        }
      }

      // 실시간 데이터 실패 시나 하위 순위 종목은 기본 데이터 반환 (가격 0)
      return {
        symbol: stock['단축코드'],
        name: stock['한글 종목명'],
        shortName: stock['한글 종목약명'],
        price: 0,
        change: 0,
        changePercent: 0,
        volume: 0,
        marketCap: stock['상장주식수'] || 0,
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

// KRX 데이터 로드 (캐싱 적용)
let krxDataCache = null;
let krxDataCacheTime = null;
const CACHE_DURATION = 60 * 60 * 1000; // 1시간

async function loadKRXData() {
  const now = Date.now();

  // 캐시 확인
  if (krxDataCache && krxDataCacheTime && (now - krxDataCacheTime) < CACHE_DURATION) {
    return krxDataCache;
  }

  try {
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

    return data;
  } catch (error) {
    console.error('❌ KRX 데이터 로드 실패:', error);
    return [];
  }
}

// KRX 데이터에서 검색
function searchInKRXData(allStocks, keyword, limit) {
  const searchKeyword = keyword.trim();

  const matchingStocks = allStocks.filter(stock => {
    const name = stock['한글 종목명'] || '';
    const shortName = stock['한글 종목약명'] || '';
    const code = stock['단축코드'] || '';

    // 정확한 매칭 우선, 부분 매칭도 허용
    return name.includes(searchKeyword) ||
      name === searchKeyword ||
      shortName.includes(searchKeyword) ||
      shortName === searchKeyword ||
      code.includes(searchKeyword) ||
      code === searchKeyword;
  });

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

    // 2위: 이름 길이 순
    if (aName.length !== bName.length) {
      return aName.length - bName.length;
    }
    return 0;
  });

  return sortedStocks.slice(0, limit);
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
