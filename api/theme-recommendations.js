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
      return res.status(200).json({
        success: true,
        data: getThemes(),
        timestamp: new Date().toISOString(),
        source: 'theme-recommendations'
      });
    }

    if (action === 'analysis') {
      // 테마별 분석 결과 반환
      if (theme) {
        const analysis = getThemeAnalysis(theme);
        return res.status(200).json({
          success: true,
          data: analysis,
          timestamp: new Date().toISOString(),
          source: 'theme-recommendations'
        });
      } else {
        const allAnalysis = getAllThemeAnalysis();
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

      const stocks = getThemeStocks(theme);
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

      const analysis = getComprehensiveAnalysis(symbol);
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
      const recommendations = getTopRecommendations(parseInt(limit), sortBy);
      
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
      const recommendations = getThemeRecommendations(theme, parseInt(limit), sortBy);
      
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

    // 기본: 모든 추천 종목 반환
    const allStocks = getAllRecommendedStocks();
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

// 테마별 추천 종목 데이터 (주달 기준 상위 10개 테마)
const themeStocks = {
  '2차전지': [
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '2차전지', 'marketCap': 45000000000000, 'description': '2차전지 소재 및 시스템'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '2차전지', 'marketCap': 38000000000000, 'description': '배터리 소재'},
    {'symbol': '003670', 'name': '포스코홀딩스', 'sector': '2차전지', 'marketCap': 28000000000000, 'description': '배터리 소재'},
    {'symbol': '000270', 'name': '기아', 'sector': '2차전지', 'marketCap': 25000000000000, 'description': '전기차 제조'},
    {'symbol': '005380', 'name': '현대차', 'sector': '2차전지', 'marketCap': 22000000000000, 'description': '전기차 제조'},
  ],
  '반도체장비': [
    {'symbol': '000660', 'name': 'SK하이닉스', 'sector': '반도체장비', 'marketCap': 55000000000000, 'description': '메모리 반도체'},
    {'symbol': '005930', 'name': '삼성전자', 'sector': '반도체장비', 'marketCap': 45000000000000, 'description': '시스템 반도체'},
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': '반도체장비', 'marketCap': 42000000000000, 'description': '반도체 장비'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '반도체장비', 'marketCap': 18000000000000, 'description': '반도체 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '반도체장비', 'marketCap': 15000000000000, 'description': '반도체 소재'},
  ],
  '전기차': [
    {'symbol': '000270', 'name': '기아', 'sector': '전기차', 'marketCap': 35000000000000, 'description': '전기차 제조'},
    {'symbol': '005380', 'name': '현대차', 'sector': '전기차', 'marketCap': 32000000000000, 'description': '전기차 제조'},
    {'symbol': '003670', 'name': '포스코홀딩스', 'sector': '전기차', 'marketCap': 28000000000000, 'description': '자동차 소재'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '전기차', 'marketCap': 18000000000000, 'description': '배터리 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '전기차', 'marketCap': 15000000000000, 'description': '배터리 시스템'},
  ],
  '수소차': [
    {'symbol': '000270', 'name': '기아', 'sector': '수소차', 'marketCap': 35000000000000, 'description': '수소차 제조'},
    {'symbol': '005380', 'name': '현대차', 'sector': '수소차', 'marketCap': 32000000000000, 'description': '수소차 제조'},
    {'symbol': '003670', 'name': '포스코홀딩스', 'sector': '수소차', 'marketCap': 28000000000000, 'description': '수소 소재'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '수소차', 'marketCap': 18000000000000, 'description': '수소 연료전지'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '수소차', 'marketCap': 15000000000000, 'description': '수소 시스템'},
  ],
  'AI': [
    {'symbol': '005930', 'name': '삼성전자', 'sector': 'AI', 'marketCap': 45000000000000, 'description': 'AI 반도체'},
    {'symbol': '000660', 'name': 'SK하이닉스', 'sector': 'AI', 'marketCap': 42000000000000, 'description': 'AI 메모리'},
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': 'AI', 'marketCap': 38000000000000, 'description': 'AI 의료'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': 'AI', 'marketCap': 18000000000000, 'description': 'AI 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': 'AI', 'marketCap': 15000000000000, 'description': 'AI 시스템'},
  ],
  '바이오': [
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': '바이오', 'marketCap': 42000000000000, 'description': '바이오 의약품'},
    {'symbol': '068270', 'name': '셀트리온', 'sector': '바이오', 'marketCap': 35000000000000, 'description': '바이오 의약품'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '바이오', 'marketCap': 18000000000000, 'description': '바이오 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '바이오', 'marketCap': 15000000000000, 'description': '바이오 시스템'},
    {'symbol': '005930', 'name': '삼성전자', 'sector': '바이오', 'marketCap': 12000000000000, 'description': '바이오 장비'},
  ],
  '자동차부품': [
    {'symbol': '000270', 'name': '기아', 'sector': '자동차부품', 'marketCap': 35000000000000, 'description': '자동차 부품'},
    {'symbol': '005380', 'name': '현대차', 'sector': '자동차부품', 'marketCap': 32000000000000, 'description': '자동차 부품'},
    {'symbol': '003670', 'name': '포스코홀딩스', 'sector': '자동차부품', 'marketCap': 28000000000000, 'description': '자동차 소재'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '자동차부품', 'marketCap': 18000000000000, 'description': '자동차 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '자동차부품', 'marketCap': 15000000000000, 'description': '자동차 전자'},
  ],
  '의료기기': [
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': '의료기기', 'marketCap': 42000000000000, 'description': '의료기기'},
    {'symbol': '068270', 'name': '셀트리온', 'sector': '의료기기', 'marketCap': 35000000000000, 'description': '의료기기'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '의료기기', 'marketCap': 18000000000000, 'description': '의료기기 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '의료기기', 'marketCap': 15000000000000, 'description': '의료기기 시스템'},
    {'symbol': '005930', 'name': '삼성전자', 'sector': '의료기기', 'marketCap': 12000000000000, 'description': '의료기기 장비'},
  ],
  '방산주': [
    {'symbol': '005930', 'name': '삼성전자', 'sector': '방산주', 'marketCap': 45000000000000, 'description': '방산 전자'},
    {'symbol': '000660', 'name': 'SK하이닉스', 'sector': '방산주', 'marketCap': 42000000000000, 'description': '방산 전자'},
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': '방산주', 'marketCap': 38000000000000, 'description': '방산 시스템'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '방산주', 'marketCap': 18000000000000, 'description': '방산 소재'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '방산주', 'marketCap': 15000000000000, 'description': '방산 시스템'},
  ],
  '밸류업': [
    {'symbol': '005930', 'name': '삼성전자', 'sector': '밸류업', 'marketCap': 45000000000000, 'description': '밸류 종목'},
    {'symbol': '000660', 'name': 'SK하이닉스', 'sector': '밸류업', 'marketCap': 42000000000000, 'description': '밸류 종목'},
    {'symbol': '207940', 'name': '삼성바이오로직스', 'sector': '밸류업', 'marketCap': 38000000000000, 'description': '밸류 종목'},
    {'symbol': '051910', 'name': 'LG화학', 'sector': '밸류업', 'marketCap': 18000000000000, 'description': '밸류 종목'},
    {'symbol': '006400', 'name': '삼성SDI', 'sector': '밸류업', 'marketCap': 15000000000000, 'description': '밸류 종목'},
  ],
};

// 테마 목록 가져오기
function getThemes() {
  return Object.keys(themeStocks);
}

// 특정 테마의 추천 종목 가져오기
function getThemeStocks(theme) {
  return themeStocks[theme] || [];
}

// 모든 테마의 추천 종목 가져오기
function getAllRecommendedStocks() {
  let allStocks = [];
  for (const theme in themeStocks) {
    allStocks = allStocks.concat(themeStocks[theme]);
  }
  return allStocks;
}

// 종목코드를 숫자로 변환하는 함수
function symbolToNumber(symbol) {
  let hash = 0;
  for (let i = 0; i < symbol.length; i++) {
    const char = symbol.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // 32bit 정수로 변환
  }
  return Math.abs(hash);
}

// 종합 투자 분석 (이평선, 거래량, 거래대금, 자본금, 분기실적 포함)
function getComprehensiveAnalysis(symbol) {
  const symbolNum = symbolToNumber(symbol);
  const basePrice = 50000 + (symbolNum % 50000);
  const randomFactor = symbolNum % 100;
  
  // 이평선 데이터
  const ma5 = basePrice + (randomFactor * 100);
  const ma20 = basePrice + (randomFactor * 80);
  const ma60 = basePrice + (randomFactor * 60);
  const currentPrice = basePrice + (randomFactor * 120);
  
  // 거래량 및 거래대금
  const volume = 1000000 + (randomFactor * 500000);
  const tradingValue = Math.round(currentPrice * volume);
  
  // 자본금 (시가총액 기반)
  const marketCap = 10000000000000 + (randomFactor * 1000000000000);
  const capital = Math.round(marketCap * 0.1); // 자본금은 시가총액의 10% 가정
  
  // 분기실적 (임시 데이터)
  const quarterlyRevenue = 1000000000000 + (randomFactor * 100000000000);
  const quarterlyProfit = 50000000000 + (randomFactor * 10000000000);
  const profitMargin = Math.round(quarterlyProfit / quarterlyRevenue * 100);
  
  // 기술적 분석
  const trend = analyzeTrend(currentPrice, ma5, ma20, ma60);
  const volumeTrend = analyzeVolumeTrend(volume, randomFactor);
  const technicalScore = calculateTechnicalScore(currentPrice, ma5, ma20, ma60, volume);
  
  // 펀더멘털 분석
  const fundamentalScore = calculateFundamentalScore(quarterlyProfit, quarterlyRevenue, marketCap);
  
  // 종합 점수 및 추천
  const totalScore = Math.round(technicalScore * 0.6 + fundamentalScore * 0.4);
  const recommendation = getRecommendation(totalScore);
  
  return {
    symbol: symbol,
    ma5: ma5,
    ma20: ma20,
    ma60: ma60,
    trend: trend,
    volume: volume,
    tradingValue: tradingValue,
    marketCap: marketCap,
    capital: capital,
    quarterlyRevenue: quarterlyRevenue,
    quarterlyProfit: quarterlyProfit,
    profitMargin: profitMargin,
    volumeTrend: volumeTrend,
    technicalScore: technicalScore,
    fundamentalScore: fundamentalScore,
    totalScore: totalScore,
    recommendation: recommendation,
    confidence: totalScore,
    lastUpdate: new Date().toISOString(),
  };
}

// 추세 분석
function analyzeTrend(current, ma5, ma20, ma60) {
  if (current > ma5 && ma5 > ma20 && ma20 > ma60) {
    return '강한상승';
  } else if (current > ma5 && ma5 > ma20) {
    return '상승';
  } else if (current > ma5) {
    return '약한상승';
  } else if (current < ma5 && ma5 < ma20 && ma20 < ma60) {
    return '강한하락';
  } else if (current < ma5 && ma5 < ma20) {
    return '하락';
  } else if (current < ma5) {
    return '약한하락';
  } else {
    return '횡보';
  }
}

// 거래량 추세 분석
function analyzeVolumeTrend(volume, randomFactor) {
  const avgVolume = 1000000 + (randomFactor * 200000);
  if (volume > avgVolume * 1.5) {
    return '급증';
  } else if (volume > avgVolume * 1.2) {
    return '증가';
  } else if (volume < avgVolume * 0.8) {
    return '감소';
  } else {
    return '보통';
  }
}

// 기술적 분석 점수 계산
function calculateTechnicalScore(current, ma5, ma20, ma60, volume) {
  let score = 50; // 기본 점수
  
  // 이평선 분석
  if (current > ma5) score += 10;
  if (ma5 > ma20) score += 10;
  if (ma20 > ma60) score += 10;
  
  // 거래량 분석
  if (volume > 1500000) score += 10;
  else if (volume < 800000) score -= 10;
  
  // 가격 위치 분석
  const pricePosition = (current - ma60) / ma60;
  if (pricePosition > 0.1) score += 10;
  else if (pricePosition < -0.1) score -= 10;
  
  return Math.max(0, Math.min(100, score));
}

// 펀더멘털 분석 점수 계산
function calculateFundamentalScore(profit, revenue, marketCap) {
  let score = 50; // 기본 점수
  
  // 수익성 분석
  const profitMargin = profit / revenue;
  if (profitMargin > 0.1) score += 20;
  else if (profitMargin > 0.05) score += 10;
  else if (profitMargin < 0) score -= 20;
  
  // 성장성 분석 (임시)
  const growthRate = 0.1 + (marketCap % 100) / 1000; // 10-20% 성장률 가정
  if (growthRate > 0.15) score += 15;
  else if (growthRate > 0.1) score += 10;
  
  // 안정성 분석 (시가총액 기반)
  if (marketCap > 50000000000000) score += 15; // 대형주
  else if (marketCap > 10000000000000) score += 10; // 중형주
  
  return Math.max(0, Math.min(100, score));
}

// 추천 결정
function getRecommendation(totalScore) {
  if (totalScore >= 80) return '강력매수';
  else if (totalScore >= 70) return '매수';
  else if (totalScore >= 60) return '약한매수';
  else if (totalScore >= 50) return '관망';
  else if (totalScore >= 40) return '약한매도';
  else if (totalScore >= 30) return '매도';
  else return '강력매도';
}

// 테마별 종합 투자 분석
function getThemeAnalysis(theme) {
  const stocks = getThemeStocks(theme);
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

  // 각 종목의 종합 분석 수행
  const analyses = stocks.map(stock => getComprehensiveAnalysis(stock.symbol));
  
  // 테마별 평균 점수 계산
  const avgTechnicalScore = analyses.reduce((sum, a) => sum + a.technicalScore, 0) / analyses.length;
  const avgFundamentalScore = analyses.reduce((sum, a) => sum + a.fundamentalScore, 0) / analyses.length;
  const avgTotalScore = analyses.reduce((sum, a) => sum + a.totalScore, 0) / analyses.length;
  
  // 최고 종목 선정
  const topStockAnalysis = analyses.reduce((a, b) => a.totalScore > b.totalScore ? a : b);
  const topStock = stocks.find(s => s.symbol === topStockAnalysis.symbol);
  
  // 거래량 추세 분석
  const volumeTrends = analyses.map(a => a.volumeTrend);
  const volumeTrend = getMostCommonVolumeTrend(volumeTrends);
  
  // 시가총액 합계
  const totalMarketCap = analyses.reduce((sum, a) => sum + a.marketCap, 0);
  
  // 추천 결정
  const recommendation = getRecommendation(Math.round(avgTotalScore));
  
  return {
    theme: theme,
    score: Math.round(avgTotalScore),
    recommendation: recommendation,
    topStock: topStock,
    analysis: `종합 분석 결과 ${Math.round(avgTotalScore)}점으로 ${avgTotalScore > 70 ? '투자 적합' : avgTotalScore > 50 ? '투자 주의' : '투자 위험'}합니다.`,
    technicalScore: Math.round(avgTechnicalScore),
    fundamentalScore: Math.round(avgFundamentalScore),
    volumeTrend: volumeTrend,
    marketCap: totalMarketCap,
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

// 특정 종목이 속한 테마들 찾기
function getStockThemes(symbol) {
  const themes = [];
  for (const theme in themeStocks) {
    const stocks = themeStocks[theme];
    if (stocks.some(stock => stock.symbol === symbol)) {
      themes.push(theme);
    }
  }
  return themes;
}

// 모든 테마 분석 결과 가져오기
function getAllThemeAnalysis() {
  return getThemes().map(theme => getThemeAnalysis(theme));
}

// 전체 추천 종목 랭킹 (모든 테마 통합, 중복 제거)
function getTopRecommendations(limit = 10, sortBy = 'totalScore') {
  const allStocks = getAllRecommendedStocks();
  
  // 중복 제거: 같은 symbol을 가진 종목 중 가장 높은 점수를 가진 것만 선택
  const uniqueStocks = {};
  
  for (const stock of allStocks) {
    const symbol = stock.symbol;
    const analysis = getComprehensiveAnalysis(symbol);
    const combinedStock = {
      ...stock,
      ...analysis
    };
    
    // 해당 symbol이 없거나, 현재 종목의 점수가 더 높으면 업데이트
    if (!uniqueStocks[symbol] || 
        combinedStock.totalScore > uniqueStocks[symbol].totalScore) {
      // 해당 종목이 속한 모든 테마 정보 추가
      const themes = getStockThemes(symbol);
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
function getThemeRecommendations(theme, limit = 5, sortBy = 'totalScore') {
  const stocks = getThemeStocks(theme);
  if (stocks.length === 0) {
    return [];
  }
  
  const analyses = stocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock.symbol)
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
function getRecommendationsByGrade(grade, limit = 10) {
  const allStocks = getAllRecommendedStocks();
  const analyses = allStocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock.symbol)
  }));
  
  const filtered = analyses.filter(analysis => analysis.recommendation === grade);
  return filtered.slice(0, limit);
}

// 위험도별 추천 종목
function getRecommendationsByRisk(riskLevel = 'medium', limit = 10) {
  const allStocks = getAllRecommendedStocks();
  const analyses = allStocks.map(stock => ({
    ...stock,
    ...getComprehensiveAnalysis(stock.symbol)
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
