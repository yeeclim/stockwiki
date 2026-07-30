import { readFile, access } from 'fs/promises';
import path from 'path';
import { checkRateLimit, getClientIp, validateString, validateInt, fail } from './_shared.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 60, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const keyword = validateString(req.query.keyword, { minLen: 1, maxLen: 50 });
  if (!keyword) {
    return fail(res, 400, '검색어가 필요합니다 (1~50자)');
  }
  const limit = validateInt(req.query.limit, { min: 1, max: 30 }) ?? 10;

  try {
    // 1단계: KRX 전체 데이터에서 검색
    const allStocks = await loadKRXData();
    const matchingStocks = searchInKRXData(allStocks, keyword, limit);

    if (matchingStocks.length === 0) {
      return res.status(404).json({
        success: false,
        error: '검색 결과가 없습니다'
      });
    }

    // 2단계: 실시간 가격 업데이트 시도 (모든 결과 대상, 실패 시 폴백)
    const results = await Promise.all(matchingStocks.map(async (stock) => {
      const code = stock['단축코드'];
      try {
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
      error: '서버 오류가 발생했습니다'
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
        await access(tryPath);
        fileContent = await readFile(tryPath, 'utf8');
        filePath = tryPath;
        break;
      } catch {
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
  // 영문 검색은 대소문자 무시
  const searchKeywordLower = searchKeyword.toLowerCase();

  const matchingStocks = allStocks.filter(stock => {
    const name = stock['한글 종목명'] || '';
    const shortName = stock['한글 종목약명'] || '';
    const engName = (stock['영문 종목명'] || '').toLowerCase();
    const code = stock['단축코드'] || '';

    const nameMatch = name.includes(searchKeyword);
    const shortNameMatch = shortName.includes(searchKeyword);
    const engNameMatch = engName.includes(searchKeywordLower);
    const codeMatch = code === searchKeyword || code.startsWith(searchKeyword);

    return nameMatch || shortNameMatch || engNameMatch || codeMatch;
  });

  // 검색 우선순위 정렬 루틴
  const sortedStocks = matchingStocks.sort((a, b) => {
    const aName = a['한글 종목명'] || '';
    const aShortName = a['한글 종목약명'] || '';
    const aEngName = (a['영문 종목명'] || '').toLowerCase();
    const bName = b['한글 종목명'] || '';
    const bShortName = b['한글 종목약명'] || '';
    const bEngName = (b['영문 종목명'] || '').toLowerCase();
    const aCode = a['단축코드'] || '';
    const bCode = b['단축코드'] || '';

    // 1위: 검색어와 완전히 일치하는 종목 최우선
    const aExact = aName === searchKeyword || aShortName === searchKeyword || aCode === searchKeyword || aEngName === searchKeywordLower;
    const bExact = bName === searchKeyword || bShortName === searchKeyword || bCode === searchKeyword || bEngName === searchKeywordLower;

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
