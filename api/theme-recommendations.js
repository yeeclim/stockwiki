import fs from 'fs';
import path from 'path';
import { fetchStockDataDirect } from './naver-stock.js';
import iconv from 'iconv-lite';
import { JSDOM } from 'jsdom';

let cachedThemes = null;
let themesLastUpdate = 0;
const THEME_CACHE_TTL = 30 * 60 * 1000; // 30분 캐시 (테마 목록은 자주 안변함)

// 테마 데이터 캐시
const themeStocksCache = {};
const STOCKS_CACHE_TTL = 5 * 60 * 1000; // 5분 캐시 (종목 데이터는 자주 변할 수 있음)

// 테마별 추천 종목 API
export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const { theme, action = 'list' } = req.query;

  try {
    console.log(`테마 추천 API 호출: ${theme || 'all'}, 액션: ${action}`);

    if (action === 'themes') {
      // 테마 목록 반환
      const themes = await getThemes();
      return res.status(200).json({
        success: true,
        data: themes.map(t => t.name),
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    if (action === 'analysis') {
      // 테마별 분석 결과 반환
      if (theme) {
        const analysis = await getThemeAnalysis(theme);
        return res.status(200).json({
          success: true,
          data: analysis,
          timestamp: new Date().toISOString(),
          source: 'theme-recommendations'
        });
      } else {
        const allAnalysis = await getAllThemeAnalysis();
        return res.status(200).json({
          success: true,
          data: allAnalysis,
          timestamp: new Date().toISOString(),
          source: 'theme-recommendations'
        });
      }
    }

    if (action === 'stocks') {
      // 특정 테마의 종목 목록 반환
      if (!theme) {
        return res.status(400).json({
          success: false,
          error: '테마가 필요합니다'
        });
      }

      const stocks = await getThemeStocks(theme);
      if (stocks.length === 0) {
        return res.status(404).json({
          success: false,
          error: '해당 테마의 종목을 찾을 수 없습니다'
        });
      }

      return res.status(200).json({
        success: true,
        theme: theme,
        data: stocks,
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    if (action === 'stock-analysis') {
      // 개별 종목 분석 반환
      const { symbol } = req.query;
      if (!symbol) {
        return res.status(400).json({
          success: false,
          error: '종목코드가 필요합니다'
        });
      }

      const analysis = {
        symbol: symbol,
        name: '종목명',
        price: 0,
        change: 0,
        changePercent: 0,
        ma5: 0,
        ma20: 0,
        ma60: 0,
        trend: '실시간 파싱 대기',
        volume: 0,
        tradingValue: 0,
        marketCap: 0,
        capital: 0,
        quarterlyRevenue: 0,
        quarterlyProfit: 0,
        profitMargin: 0,
        volumeTrend: '대기',
        technicalScore: 0,
        fundamentalScore: 0,
        totalScore: 0,
        recommendation: '관망',
        confidence: 0,
        lastUpdate: new Date().toISOString(),
      };
      return res.status(200).json({
        success: true,
        symbol: symbol,
        data: analysis,
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    if (action === 'recommendations') {
      // 추천 종목 랭킹 반환
      const { limit = 10, sortBy = 'totalScore' } = req.query;
      const recommendations = await getTopRecommendations(parseInt(limit), sortBy);

      return res.status(200).json({
        success: true,
        data: recommendations,
        count: recommendations.length,
        sortBy: sortBy,
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    if (action === 'theme-recommendations') {
      // 특정 테마의 추천 종목 반환
      if (!theme) {
        return res.status(400).json({
          success: false,
          error: '테마가 필요합니다'
        });
      }

      const { limit = 5, sortBy = 'totalScore' } = req.query;
      const recommendations = await getThemeRecommendations(theme, parseInt(limit), sortBy);

      return res.status(200).json({
        success: true,
        theme: theme,
        data: recommendations,
        count: recommendations.length,
        sortBy: sortBy,
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    // 기본: 모든 추천 종목 반환 (서버 부하 방지를 위해 랜덤 3개 테마만)
    const allStocks = await getAllRecommendedStocks();
    return res.status(200).json({
      success: true,
      data: allStocks,
      timestamp: new Date().toISOString(),
      source: 'theme-recommendations'
    });

  } catch (error) {
    console.error('테마 추천 API 오류:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

// 네이버 증권 테마 목록 실시간 스크래핑
async function scrapeNaverThemeList() {
  try {
    const response = await fetch('https://finance.naver.com/sise/theme.naver');
    if (!response.ok) return [];

    const arrayBuffer = await response.arrayBuffer();
    const html = iconv.decode(Buffer.from(arrayBuffer), 'euc-kr');

    const dom = new JSDOM(html);
    const doc = dom.window.document;

    const themes = [];
    const rows = doc.querySelectorAll('table.type_1.theme tbody tr');

    rows.forEach(row => {
      const nameCol = row.querySelector('.col_type1 a');
      const descCol = row.querySelector('.col_type2');
      if (!nameCol) return;

      const match = nameCol.href.match(/no=(\d+)/);
      if (match) {
        themes.push({
          id: match[1],
          name: nameCol.textContent.trim(),
          description: descCol ? descCol.textContent.trim() : `${nameCol.textContent.trim()} 관련 테마`,
          url: `https://finance.naver.com${nameCol.href}`
        });
      }
    });

    return themes;
  } catch (error) {
    console.error('테마 리스트 스크래핑 실패:', error);
    return [];
  }
}

// 네이버 증권 특정 테마 소속 종목 실시간 스크래핑
async function scrapeNaverThemeStocks(themeId, themeName) {
  try {
    const themeUrl = `https://finance.naver.com/sise/sise_group_detail.naver?type=theme&no=${themeId}`;
    const response = await fetch(themeUrl);
    if (!response.ok) return [];

    const arrayBuffer = await response.arrayBuffer();
    const html = iconv.decode(Buffer.from(arrayBuffer), 'euc-kr');

    const dom = new JSDOM(html);
    const doc = dom.window.document;

    const stocks = [];
    const rows = doc.querySelectorAll('table.type_5 tbody tr');

    rows.forEach(row => {
      if (row.querySelector('.kline') || row.querySelector('.blank_08')) return;

      const nameArea = row.querySelector('.name_area a');
      if (!nameArea) return;

      const name = nameArea.textContent.trim();
      const symbolMatch = nameArea.href.match(/code=(\d+)/);
      const symbol = symbolMatch ? symbolMatch[1] : '';

      const numberCells = row.querySelectorAll('td.number');
      if (numberCells.length < 3) return;

      const price = parseInt(numberCells[0].textContent.replace(/,/g, '').trim()) || 0;
      const changeText = numberCells[1].textContent.replace(/,/g, '').trim();
      let change = parseInt(changeText) || 0;

      // 하락인 경우 음수 처리
      const nv01 = row.querySelector('.nv01'); // 하락 클래스
      if (nv01 && change > 0) change = -change;

      const percentText = numberCells[2].textContent.replace(/,/g, '').replace(/%/g, '').trim();
      const changePercent = parseFloat(percentText) || 0;

      if (symbol && name) {
        stocks.push({
          symbol,
          name,
          price,
          change,
          changePercent,
          sector: themeName, // fallback용
          description: `네이버 금융 ${themeName} 종목`
        });
      }
    });

    // 테마별 상위 5~10개만 리턴
    return stocks.slice(0, 10);
  } catch (error) {
    console.error(`테마 ${themeId} 스크래핑 실패:`, error);
    return [];
  }
}

// 테마 목록 가져오기 (캐시 적용)
async function getThemes() {
  const now = Date.now();
  if (cachedThemes && (now - themesLastUpdate < THEME_CACHE_TTL)) {
    return cachedThemes;
  }

  const themes = await scrapeNaverThemeList();
  if (themes && themes.length > 0) {
    // 서버 부하/타이머 방지를 위해 상위 50개 정도만 사용
    cachedThemes = themes.slice(0, 50);
    themesLastUpdate = now;
    return cachedThemes;
  }
  return [];
}

// 특정 테마명으로 테마 메타데이터 찾기
async function getThemeByName(themeName) {
  const themes = await getThemes();
  return themes.find(t => t.name === themeName);
}

// 특정 테마의 추천 종목 가져오기 (캐시 적용)
async function getThemeStocks(themeName) {
  const now = Date.now();
  if (themeStocksCache[themeName] && (now - themeStocksCache[themeName].lastUpdate < STOCKS_CACHE_TTL)) {
    return themeStocksCache[themeName].data;
  }

  const themeMeta = await getThemeByName(themeName);
  if (!themeMeta) {
    console.warn(`테마를 찾을 수 없음: ${themeName}`);
    return [];
  }

  const stocks = await scrapeNaverThemeStocks(themeMeta.id, themeName);
  if (stocks && stocks.length > 0) {
    themeStocksCache[themeName] = {
      data: stocks,
      lastUpdate: now
    };
  }
  return stocks;
}

// 종합 투자 분석 
// (실시간 크롤링된 데이터가 넘어올 것이므로 가짜 지표 생성 삭제)
function getComprehensiveAnalysis(stockData) {
  return {
    symbol: stockData.symbol,
    name: stockData.name,
    price: stockData.price,
    change: stockData.change,
    changePercent: stockData.changePercent,
    ma5: 0,
    ma20: 0,
    ma60: 0,
    trend: '실시간 파싱 대기',
    volume: 0,
    tradingValue: 0,
    marketCap: 0, // 상세 파싱 전까지 대기
    capital: 0,
    quarterlyRevenue: 0,
    quarterlyProfit: 0,
    profitMargin: 0,
    volumeTrend: '대기',
    technicalScore: 0,
    fundamentalScore: 0,
    totalScore: 0,
    recommendation: '관망',
    confidence: 0,
    lastUpdate: new Date().toISOString(),
  };
}

// 모든 테마의 최상위 추천 종목 가져오기
async function getAllRecommendedStocks() {
  const themes = await getThemes();
  let allStocks = [];

  // 전체 다 긁으면 네이버 IP 블록 가능성이 있으므로 랜덤하게 3~5개 테마만 골라서 스크래핑
  const shuffledThemes = [...themes].sort(() => 0.5 - Math.random()).slice(0, 3);

  for (const theme of shuffledThemes) {
    const stocks = await getThemeStocks(theme.name);
    // 각 테마별로 top 1~2개만 전체 목록에 추가
    if (stocks.length > 0) {
      allStocks = allStocks.concat(stocks.slice(0, 2));
    }
  }
  return allStocks;
}

// 모든 테마의 최고 분석 가져오기
async function getAllThemeAnalysis() {
  const themesMeta = await getThemes();
  const sortedThemes = [...themesMeta].slice(0, 5); // 주요 5개 테마만 분석 반환 (서버 부하 방지)
  const analysisList = [];
  for (const themeMeta of sortedThemes) {
    analysisList.push(await getThemeAnalysis(themeMeta.name));
  }
  return analysisList;
}



// 테마별 종합 투자 분석
async function getThemeAnalysis(theme) {
  const stocks = await getThemeStocks(theme);
  if (stocks.length === 0) {
    return {
      theme: theme,
      score: 0,
      recommendation: '분석 불가',
      topStock: null,
      analysis: '해당 테마의 종목이 없습니다.',
      technicalScore: 0,
      fundamentalScore: 0,
      volumeTrend: '보통',
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
    };
  }

  return {
    theme: theme,
    score: 0,
    recommendation: '분석 대기',
    topStock: stocks[0],
    analysis: `실시간 테마 분석 데이터를 수집 중입니다.`,
    technicalScore: 0,
    fundamentalScore: 0,
    volumeTrend: '대기',
    marketCap: 0,
    stockCount: stocks.length,
    lastUpdate: new Date().toISOString(),
  };
}

// 가장 많은 거래량 추세 찾기
function getMostCommonVolumeTrend(trends) {
  const counts = {};
  for (const trend of trends) {
    counts[trend] = (counts[trend] || 0) + 1;
  }
  return Object.entries(counts).reduce((a, b) => a[1] > b[1] ? a : b)[0];
}

// 특정 종목이 속한 테마들 찾기 (동적 환경에서는 모든 테마를 스크래핑해 검색해야 함 - 비용 높음)
async function getStockThemes(symbol) {
  const themesMeta = await getThemes();
  const matchingThemes = [];

  // 서버 보호를 위해 상위 10개 메타만 조사
  const themesToCheck = themesMeta.slice(0, 10);

  for (const t of themesToCheck) {
    const list = await getThemeStocks(t.name);
    if (list.some(stock => stock.symbol === symbol)) {
      matchingThemes.push(t.name);
    }
  }
  return matchingThemes;
}


// 전체 추천 종목 랭킹 (모든 테마 통합, 중복 제거)
async function getTopRecommendations(limit = 10, sortBy = 'totalScore') {
  const allStocks = await getAllRecommendedStocks();

  // 중복 제거: 같은 symbol을 가진 종목 중 가장 높은 점수를 가진 것만 선택
  const uniqueStocks = {};

  for (const stock of allStocks) {
    const symbol = stock.symbol;
    const analysis = getComprehensiveAnalysis(stock);
    const combinedStock = {
      ...stock,
      ...analysis
    };

    // 해당 symbol이 없거나, 현재 종목의 점수가 더 높으면 업데이트
    if (!uniqueStocks[symbol] ||
      combinedStock.totalScore > uniqueStocks[symbol].totalScore) {
      // 해당 종목이 속한 모든 테마 정보 추가
      const themes = await getStockThemes(symbol);
      combinedStock.themes = themes;
      combinedStock.themeCount = themes.length;
      uniqueStocks[symbol] = combinedStock;
    }
  }

  const analyses = Object.values(uniqueStocks);

  // 정렬
  analyses.sort((a, b) => {
    if (sortBy === 'totalScore') {
      return b.totalScore - a.totalScore;
    } else if (sortBy === 'technicalScore') {
      return b.technicalScore - a.technicalScore;
    } else if (sortBy === 'fundamentalScore') {
      return b.fundamentalScore - a.fundamentalScore;
    } else if (sortBy === 'marketCap') {
      return b.marketCap - a.marketCap;
    } else if (sortBy === 'volume') {
      return b.volume - a.volume;
    } else if (sortBy === 'tradingValue') {
      return b.tradingValue - a.tradingValue;
    }
    return b.totalScore - a.totalScore;
  });

  return analyses.slice(0, limit);
}

// 특정 테마의 추천 종목 랭킹
async function getThemeRecommendations(theme, limit = 5, sortBy = 'totalScore') {
  const stocks = await getThemeStocks(theme);
  if (stocks.length === 0) {
    return [];
  }

  const analyses = stocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock)
  }));

  // 정렬
  analyses.sort((a, b) => {
    if (sortBy === 'totalScore') {
      return b.totalScore - a.totalScore;
    } else if (sortBy === 'technicalScore') {
      return b.technicalScore - a.technicalScore;
    } else if (sortBy === 'fundamentalScore') {
      return b.fundamentalScore - a.fundamentalScore;
    } else if (sortBy === 'marketCap') {
      return b.marketCap - a.marketCap;
    } else if (sortBy === 'volume') {
      return b.volume - a.volume;
    } else if (sortBy === 'tradingValue') {
      return b.tradingValue - a.tradingValue;
    }
    return b.totalScore - a.totalScore;
  });

  return analyses.slice(0, limit);
}

// 추천 종목 필터링 (추천 등급별)
async function getRecommendationsByGrade(grade, limit = 10) {
  const allStocks = await getAllRecommendedStocks();
  const analyses = allStocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock)
  }));

  const filtered = analyses.filter(analysis => analysis.recommendation === grade);
  return filtered.slice(0, limit);
}

// 위험도별 추천 종목
async function getRecommendationsByRisk(riskLevel = 'medium', limit = 10) {
  const allStocks = await getAllRecommendedStocks();
  const analyses = allStocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock)
  }));

  let filtered;
  if (riskLevel === 'low') {
    // 안전한 종목 (대형주, 높은 펀더멘털 점수)
    filtered = analyses.filter(analysis =>
      analysis.marketCap > 50000000000000 &&
      analysis.fundamentalScore > 70 &&
      analysis.totalScore > 60
    );
  } else if (riskLevel === 'high') {
    // 고위험 고수익 종목 (소형주, 높은 기술적 점수)
    filtered = analyses.filter(analysis =>
      analysis.marketCap < 20000000000000 &&
      analysis.technicalScore > 80 &&
      analysis.volumeTrend === '급증'
    );
  } else {
    // 중간 위험도 (균형잡힌 종목)
    filtered = analyses.filter(analysis =>
      analysis.totalScore >= 50 &&
      analysis.totalScore <= 80 &&
      analysis.marketCap >= 20000000000000
    );
  }

  filtered.sort((a, b) => b.totalScore - a.totalScore);
  return filtered.slice(0, limit);
}
