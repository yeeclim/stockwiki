import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;

class KrxLoader {
  // 테마별 추천 종목 데이터 (주달 기준 상위 10개 테마)
  static const Map<String, List<Map<String, dynamic>>> _themeStocks = {
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
  static List<String> getThemes() {
    return _themeStocks.keys.toList();
  }

  // 특정 테마의 추천 종목 가져오기
  static List<Map<String, dynamic>> getThemeStocks(String theme) {
    return _themeStocks[theme] ?? [];
  }

  // 모든 테마의 추천 종목 가져오기
  static List<Map<String, dynamic>> getAllRecommendedStocks() {
    List<Map<String, dynamic>> allStocks = [];
    for (String theme in _themeStocks.keys) {
      allStocks.addAll(_themeStocks[theme]!);
    }
    return allStocks;
  }

  // 종합 투자 분석 (이평선, 거래량, 거래대금, 자본금, 분기실적 포함)
  static Map<String, dynamic> getComprehensiveAnalysis(String symbol) {
    // 실제로는 API에서 실시간 데이터를 가져와야 함
    final basePrice = 50000 + (symbol.hashCode % 50000);
    final randomFactor = symbol.hashCode % 100;
    
    // 이평선 데이터
    final ma5 = basePrice + (randomFactor * 100);
    final ma20 = basePrice + (randomFactor * 80);
    final ma60 = basePrice + (randomFactor * 60);
    final currentPrice = basePrice + (randomFactor * 120);
    
    // 거래량 및 거래대금
    final volume = 1000000 + (randomFactor * 500000);
    final tradingValue = (currentPrice * volume).round();
    
    // 자본금 (시가총액 기반)
    final marketCap = 10000000000000 + (randomFactor * 1000000000000);
    final capital = (marketCap * 0.1).round(); // 자본금은 시가총액의 10% 가정
    
    // 분기실적 (임시 데이터)
    final quarterlyRevenue = 1000000000000 + (randomFactor * 100000000000);
    final quarterlyProfit = 50000000000 + (randomFactor * 10000000000);
    final profitMargin = (quarterlyProfit / quarterlyRevenue * 100).round();
    
    // 기술적 분석
    final trend = _analyzeTrend(currentPrice, ma5, ma20, ma60);
    final volumeTrend = _analyzeVolumeTrend(volume, randomFactor);
    final technicalScore = _calculateTechnicalScore(currentPrice, ma5, ma20, ma60, volume);
    
    // 펀더멘털 분석
    final fundamentalScore = _calculateFundamentalScore(quarterlyProfit, quarterlyRevenue, marketCap);
    
    // 종합 점수 및 추천
    final totalScore = (technicalScore * 0.6 + fundamentalScore * 0.4).round();
    final recommendation = _getRecommendation(totalScore);
    
    return {
      'symbol': symbol,
      'currentPrice': currentPrice,
      'ma5': ma5,
      'ma20': ma20,
      'ma60': ma60,
      'trend': trend,
      'volume': volume,
      'tradingValue': tradingValue,
      'marketCap': marketCap,
      'capital': capital,
      'quarterlyRevenue': quarterlyRevenue,
      'quarterlyProfit': quarterlyProfit,
      'profitMargin': profitMargin,
      'volumeTrend': volumeTrend,
      'technicalScore': technicalScore,
      'fundamentalScore': fundamentalScore,
      'totalScore': totalScore,
      'recommendation': recommendation,
      'confidence': totalScore,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  // 추세 분석
  static String _analyzeTrend(double current, double ma5, double ma20, double ma60) {
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
  static String _analyzeVolumeTrend(int volume, int randomFactor) {
    final avgVolume = 1000000 + (randomFactor * 200000);
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
  static int _calculateTechnicalScore(double current, double ma5, double ma20, double ma60, int volume) {
    int score = 50; // 기본 점수
    
    // 이평선 분석
    if (current > ma5) score += 10;
    if (ma5 > ma20) score += 10;
    if (ma20 > ma60) score += 10;
    
    // 거래량 분석
    if (volume > 1500000) score += 10;
    else if (volume < 800000) score -= 10;
    
    // 가격 위치 분석
    final pricePosition = (current - ma60) / ma60;
    if (pricePosition > 0.1) score += 10;
    else if (pricePosition < -0.1) score -= 10;
    
    return score.clamp(0, 100);
  }

  // 펀더멘털 분석 점수 계산
  static int _calculateFundamentalScore(int profit, int revenue, int marketCap) {
    int score = 50; // 기본 점수
    
    // 수익성 분석
    final profitMargin = profit / revenue;
    if (profitMargin > 0.1) score += 20;
    else if (profitMargin > 0.05) score += 10;
    else if (profitMargin < 0) score -= 20;
    
    // 성장성 분석 (임시)
    final growthRate = 0.1 + (marketCap % 100) / 1000; // 10-20% 성장률 가정
    if (growthRate > 0.15) score += 15;
    else if (growthRate > 0.1) score += 10;
    
    // 안정성 분석 (시가총액 기반)
    if (marketCap > 50000000000000) score += 15; // 대형주
    else if (marketCap > 10000000000000) score += 10; // 중형주
    
    return score.clamp(0, 100);
  }

  // 추천 결정
  static String _getRecommendation(int totalScore) {
    if (totalScore >= 80) return '강력매수';
    else if (totalScore >= 70) return '매수';
    else if (totalScore >= 60) return '약한매수';
    else if (totalScore >= 50) return '관망';
    else if (totalScore >= 40) return '약한매도';
    else if (totalScore >= 30) return '매도';
    else return '강력매도';
  }

  // 테마별 종합 투자 분석
  static Map<String, dynamic> getThemeAnalysis(String theme) {
    final stocks = getThemeStocks(theme);
    if (stocks.isEmpty) {
      return {
        'theme': theme,
        'score': 0,
        'recommendation': '분석 불가',
        'topStock': null,
        'analysis': '해당 테마의 종목이 없습니다.',
        'technicalScore': 0,
        'fundamentalScore': 0,
        'volumeTrend': '보통',
        'marketCap': 0,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    }

    // 각 종목의 종합 분석 수행
    final analyses = stocks.map((stock) => getComprehensiveAnalysis(stock['symbol'])).toList();
    
    // 테마별 평균 점수 계산
    final avgTechnicalScore = analyses.map((a) => a['technicalScore'] as int).reduce((a, b) => a + b) / analyses.length;
    final avgFundamentalScore = analyses.map((a) => a['fundamentalScore'] as int).reduce((a, b) => a + b) / analyses.length;
    final avgTotalScore = analyses.map((a) => a['totalScore'] as int).reduce((a, b) => a + b) / analyses.length;
    
    // 최고 종목 선정
    final topStockAnalysis = analyses.reduce((a, b) => (a['totalScore'] as int) > (b['totalScore'] as int) ? a : b);
    final topStock = stocks.firstWhere((s) => s['symbol'] == topStockAnalysis['symbol']);
    
    // 거래량 추세 분석
    final volumeTrends = analyses.map((a) => a['volumeTrend'] as String).toList();
    final volumeTrend = _getMostCommonVolumeTrend(volumeTrends);
    
    // 시가총액 합계
    final totalMarketCap = analyses.map((a) => a['marketCap'] as int).reduce((a, b) => a + b);
    
    // 추천 결정
    final recommendation = _getRecommendation(avgTotalScore.round());
    
    return {
      'theme': theme,
      'score': avgTotalScore.round(),
      'recommendation': recommendation,
      'topStock': topStock,
      'analysis': '종합 분석 결과 ${avgTotalScore.round()}점으로 ${avgTotalScore > 70 ? '투자 적합' : avgTotalScore > 50 ? '투자 주의' : '투자 위험'}합니다.',
      'technicalScore': avgTechnicalScore.round(),
      'fundamentalScore': avgFundamentalScore.round(),
      'volumeTrend': volumeTrend,
      'marketCap': totalMarketCap,
      'stockCount': stocks.length,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  // 가장 많은 거래량 추세 찾기
  static String _getMostCommonVolumeTrend(List<String> trends) {
    final counts = <String, int>{};
    for (final trend in trends) {
      counts[trend] = (counts[trend] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // 모든 테마 분석 결과 가져오기
  static List<Map<String, dynamic>> getAllThemeAnalysis() {
    return getThemes().map((theme) => getThemeAnalysis(theme)).toList();
  }
}