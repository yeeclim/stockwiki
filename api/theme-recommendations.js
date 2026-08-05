import fs from 'fs';
import path from 'path';
import { fetchStockDataDirect } from './_naver-stock.js';
import iconv from 'iconv-lite';
import { JSDOM } from 'jsdom';

let cachedThemes = null;
let themesLastUpdate = 0;
const THEME_CACHE_TTL = 30 * 60 * 1000;

const themeStocksCache = {};
const STOCKS_CACHE_TTL = 5 * 60 * 1000;

// 기술적 지표 캐시 (1시간)
const technicalCache = {};
const TECHNICAL_CACHE_TTL = 60 * 60 * 1000;

// 시총 필터 기준: 5,000억원 이상
const MIN_MARKET_CAP_EOK = 5_000; // 억원 단위

// 한국 기업이 세계 시장에 영향을 주는 글로벌 테마 키워드 화이트리스트
// 이 키워드 중 하나라도 포함된 테마만 노출
const GLOBAL_THEME_KEYWORDS = [
  // 반도체·소재·부품
  '반도체', '메모리', '파운드리', '시스템반도체', 'HBM', 'DRAM', 'NAND',
  // 배터리·전기차·에너지저장
  '2차전지', '배터리', '전기차', 'EV', '전고체', '양극재', '음극재', '분리막', '전해질',
  // 디스플레이
  '디스플레이', 'OLED', 'LCD', 'QLED', '마이크로LED',
  // 자동차·모빌리티
  '자동차', '모빌리티', '자율주행', '전장',
  // 조선·해양
  '조선', '해양플랜트', 'LNG',
  // 방산·우주
  '방산', '방위', '우주', '항공', '드론',
  // AI·로봇·자동화
  'AI', '인공지능', '로봇', '자동화', '머신러닝', '데이터센터', '클라우드', 'GPU',
  // 에너지·수소·원자력
  '수소', '신재생', '태양광', '풍력', '원자력', '핵융합', '소형모듈원자로', 'SMR',
  '전력', '전력기기', '변압기', '송전',
  // 소재·철강·화학
  '철강', '소재', '희토류', '구리', '알루미늄', '석유화학', '정유', '화학',
  // 바이오·헬스케어
  '바이오', '제약', '신약', '의료기기', '헬스케어', 'mRNA', '항암',
  // 통신·네트워크
  '5G', '6G', '네트워크', '위성',
  // 소부장 (소재·부품·장비)
  '소부장', '장비',
  // K-뷰티·글로벌 소비재
  'K-뷰티', '화장품', 'K뷰티',
  // 게임·엔터 (글로벌 IP)
  '게임', '엔터테인먼트', '콘텐츠', 'K-콘텐츠',
];

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

      // 거래량 (4번째 컬럼)
      const volume = numberCells.length >= 4
        ? parseInt(numberCells[3].textContent.replace(/,/g, '').trim()) || 0
        : 0;

      if (symbol && name) {
        stocks.push({ symbol, name, price, change, changePercent, volume, sector: themeName,
          description: `네이버 금융 ${themeName} 종목` });
      }
    });

    // 종목별 실제 시총 조회 후 필터링
    const withCap = await Promise.all(
      stocks.map(async s => {
        const cap = await fetchMarketCapEok(s.symbol);
        return { ...s, marketCapEok: cap, marketCap: cap * 100_000_000 };
      })
    );

    const filtered = withCap.filter(s => s.marketCapEok >= MIN_MARKET_CAP_EOK);

    // 테마별 상위 10개만 리턴
    return filtered.slice(0, 10);
  } catch (error) {
    console.error(`테마 ${themeId} 스크래핑 실패:`, error);
    return [];
  }
}

// 네이버 itemSummary API로 시가총액(억원) 조회
const marketCapCache = {};
async function fetchMarketCapEok(symbol) {
  if (marketCapCache[symbol] !== undefined) return marketCapCache[symbol];
  try {
    const res = await fetch(
      `https://api.finance.naver.com/service/itemSummary.nhn?itemcode=${symbol}`,
      { headers: { 'Referer': 'https://finance.naver.com/' } }
    );
    if (!res.ok) return 0;
    const data = await res.json();
    // marketSum은 백만원 단위 → 100으로 나누면 억원
    const cap = Math.floor((parseInt(data.marketSum) || 0) / 100);
    marketCapCache[symbol] = cap;
    return cap;
  } catch {
    return 0;
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
    // 글로벌 영향력 있는 테마만 필터링
    const globalThemes = themes.filter(t =>
      GLOBAL_THEME_KEYWORDS.some(kw => t.name.includes(kw))
    );
    cachedThemes = globalThemes.slice(0, 50);
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

// ── 기술적 지표 (MA20, MA60, 52주 고가) ──────────────────────────

async function fetchTechnicalData(symbol) {
  const now = Date.now();
  const cached = technicalCache[symbol];
  if (cached && (now - cached.lastUpdate < TECHNICAL_CACHE_TTL)) {
    return cached.data;
  }

  try {
    const url = `https://fchart.stock.naver.com/sise.nhn?symbol=${symbol}&timeframe=day&count=260&requestType=0`;
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;

    const xml = await res.text();
    const closes = [];
    const re = /<item data="([^"]+)"/g;
    let m;
    while ((m = re.exec(xml)) !== null) {
      const parts = m[1].split('|');
      if (parts.length >= 5) {
        const c = parseInt(parts[4]);
        if (c > 0) closes.push(c);
      }
    }

    if (closes.length < 20) return null;

    const calcMA = (n) => {
      if (closes.length < n) return null;
      const slice = closes.slice(-n);
      return slice.reduce((a, b) => a + b, 0) / n;
    };

    const data = {
      ma20: calcMA(20),
      ma60: calcMA(60),
      high52w: Math.max(...closes.slice(-252)),
    };

    technicalCache[symbol] = { data, lastUpdate: now };
    return data;
  } catch {
    return null;
  }
}

// 기술적 필터 — 가치투자 기준 (MA60 이하 저평가 종목 발굴)
// - pass=false → 추천 목록에서 제외
// - warning → 카드에 뱃지로 경고 표시 (제외하지 않음)
function applyTechnicalFilter(price, tech) {
  // 데이터 없으면 제외 (기존: 통과 → 변경: 제외)
  if (!tech || !price) return { pass: false, warning: null };

  const { ma20, ma60, high52w } = tech;

  // ① MA60 데이터 없으면 제외
  if (!ma60) return { pass: false, warning: null };

  // ② 핵심 조건: 현재가 < MA60 (이평선 아래 = 저평가 구간)
  if (price >= ma60) return { pass: false, warning: null };

  // ③ 과도한 급락 제외: MA60 대비 40% 이상 하락 (펀더멘털 붕괴 가능성)
  if (price < ma60 * 0.60) return { pass: false, warning: null };

  // ④ 경고 뱃지
  let warning = null;
  if (ma20 && ma20 < ma60)       warning = '데드크로스 주의';  // 단기도 하락 추세
  else if (ma20 && price < ma20) warning = 'MA20 아래';        // 단기 하락 중

  return { pass: true, warning };
}

// ── 점수 산정 (100점 만점) — 가치투자 기준 ────────────────────────
// · 저평가도  50점: MA60 대비 할인율 (많이 빠질수록 고점수)
// · 거래량    30점: 유동성 확인
// · 반등 신호 20점: 오늘 소폭 상승 = 바닥 탈출 신호
function calcThemeScore(stock) {
  const cp  = stock.changePercent ?? 0;
  const vol = stock.volume ?? 0;
  const price = stock.price ?? 0;
  const ma60  = stock.ma60 ?? 0;

  // ① 저평가도 (MA60 대비 할인율)
  let valueScore = 0;
  if (ma60 && price) {
    const discount = (ma60 - price) / ma60 * 100; // MA60 대비 몇% 아래인지
    if (discount >= 30)      valueScore = 50;
    else if (discount >= 20) valueScore = 42;
    else if (discount >= 15) valueScore = 35;
    else if (discount >= 10) valueScore = 26;
    else if (discount >= 5)  valueScore = 16;
    else                     valueScore = 8;
  }

  // ② 거래량 (유동성)
  let volScore;
  if (vol >= 1_000_000)    volScore = 30;
  else if (vol >= 300_000) volScore = 24;
  else if (vol >= 100_000) volScore = 17;
  else if (vol >= 30_000)  volScore = 10;
  else if (vol > 0)        volScore = 5;
  else                     volScore = 8; // 미수집 시 중립

  // ③ 반등 신호 (당일 소폭 상승 = 바닥 다지기)
  let reboundScore;
  if (cp >= 3)        reboundScore = 20; // 강한 반등
  else if (cp >= 1)   reboundScore = 16;
  else if (cp >= 0)   reboundScore = 10; // 보합
  else if (cp >= -2)  reboundScore = 4;  // 소폭 하락
  else                reboundScore = 0;  // 급락 중

  return valueScore + volScore + reboundScore;
}

function scoreToRecommendation(score, cp) {
  if (score >= 75) return '매수 적극 검토';
  if (score >= 55) return '분할 매수 검토';
  if (score >= 35) return '관망';
  return '대기';
}

// 테마 추천에 노출할 최소 점수 — 스크리닝처럼 '관망/대기' 등급은 숨기고
// '분할 매수 검토' 이상만 노출
const MIN_THEME_SCORE = 55;

function buildThemeReasons(stock, score) {
  const cp    = stock.changePercent ?? 0;
  const vol   = stock.volume ?? 0;
  const price = stock.price ?? 0;
  const ma60  = stock.ma60 ?? 0;
  const reasons = [];

  // 저평가 근거
  if (ma60 && price) {
    const discount = ((ma60 - price) / ma60 * 100).toFixed(1);
    reasons.push(`60일 이평선(${ma60.toLocaleString()}원) 대비 ${discount}% 저평가 구간`);
  }

  // 당일 반등 신호
  if (cp >= 3) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 강한 반등 — 바닥 탈출 신호`);
  } else if (cp >= 1) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 소폭 반등 — 매수세 유입 감지`);
  } else if (cp >= 0) {
    reasons.push(`오늘 보합 — 추가 하락 멈춤, 반등 대기`);
  } else {
    reasons.push(`오늘 ${cp.toFixed(2)}% 하락 중 — 추가 확인 권장`);
  }

  if (vol >= 300_000) {
    reasons.push(`거래량 ${vol.toLocaleString()}주 — 유동성 충분`);
  } else if (vol > 0) {
    reasons.push(`거래량 ${vol.toLocaleString()}주`);
  }

  reasons.push(`${stock.sector} 테마 — 저평가 스크리닝 점수 ${score}점 / 100점`);
  return reasons;
}

function getComprehensiveAnalysis(stockData) {
  const totalScore = calcThemeScore(stockData);
  const recommendation = scoreToRecommendation(totalScore, stockData.changePercent ?? 0);
  return {
    symbol: stockData.symbol,
    name: stockData.name,
    price: stockData.price,
    change: stockData.change,
    changePercent: stockData.changePercent,
    volume: stockData.volume ?? 0,
    totalScore,
    technicalScore: totalScore,   // 호환성 유지
    fundamentalScore: 0,
    recommendation,
    reasons: buildThemeReasons(stockData, totalScore),
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

// 특정 테마의 추천 종목 랭킹 (기술적 필터 적용)
async function getThemeRecommendations(theme, limit = 5, sortBy = 'totalScore') {
  const stocks = await getThemeStocks(theme);
  if (stocks.length === 0) return [];

  // 기술적 데이터 병렬 fetch
  const techResults = await Promise.all(
    stocks.map(s => fetchTechnicalData(s.symbol).catch(() => null))
  );

  const analyses = [];
  for (let i = 0; i < stocks.length; i++) {
    const stock = stocks[i];
    const tech = techResults[i];
    const filterResult = applyTechnicalFilter(stock.price, tech);

    if (!filterResult.pass) {
      console.log(`[기술필터 제외] ${stock.name}(${stock.symbol})`);
      continue;
    }

    const analysis = getComprehensiveAnalysis(stock);

    // 점수가 낮으면 (관망/대기 등급) 추천 목록에서 제외
    if (analysis.totalScore < MIN_THEME_SCORE) {
      console.log(`[점수 미달 제외] ${stock.name}(${stock.symbol}) score=${analysis.totalScore}`);
      continue;
    }

    // MA 정보 reasons에 추가
    if (tech?.ma20) {
      const ma20Diff = ((stock.price - tech.ma20) / tech.ma20 * 100).toFixed(1);
      analysis.reasons = analysis.reasons ?? [];
      analysis.reasons.push(`MA20 대비 +${ma20Diff}% — 상승 추세 유지`);
      if (tech.ma60) {
        analysis.reasons.push(`MA20(${Math.round(tech.ma20).toLocaleString()}) > MA60(${Math.round(tech.ma60).toLocaleString()}) — 골든크로스 배열`);
      }
      if (tech.high52w) {
        const ratio52w = (stock.price / tech.high52w * 100).toFixed(1);
        analysis.reasons.push(`52주 고가 대비 ${ratio52w}%`);
      }
    }
    if (filterResult.warning) {
      analysis.reasons = analysis.reasons ?? [];
      analysis.reasons.push(`⚠ ${filterResult.warning} — 신규 진입 시 주의`);
    }

    analyses.push({
      ...stock,
      ...analysis,
      ma20: tech?.ma20 ? Math.round(tech.ma20) : null,
      ma60: tech?.ma60 ? Math.round(tech.ma60) : null,
      high52w: tech?.high52w ?? null,
    });
  }

  analyses.sort((a, b) => {
    if (sortBy === 'totalScore') return b.totalScore - a.totalScore;
    if (sortBy === 'technicalScore') return b.technicalScore - a.technicalScore;
    if (sortBy === 'volume') return b.volume - a.volume;
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
