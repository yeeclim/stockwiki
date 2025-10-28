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

  // 이평선 분석 (임시 데이터)
  static Map<String, dynamic> getMovingAverageAnalysis(String symbol) {
    // 실제로는 API에서 이평선 데이터를 가져와야 함
    return {
      'symbol': symbol,
      'ma5': 75000 + (symbol.hashCode % 10000),
      'ma20': 72000 + (symbol.hashCode % 8000),
      'ma60': 70000 + (symbol.hashCode % 6000),
      'trend': '상승', // 상승, 하락, 횡보
      'recommendation': '매수', // 매수, 매도, 관망
      'confidence': 85, // 신뢰도 0-100
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  // 테마별 투자 적합성 분석
  static Map<String, dynamic> getThemeAnalysis(String theme) {
    final stocks = getThemeStocks(theme);
    if (stocks.isEmpty) {
      return {
        'theme': theme,
        'score': 0,
        'recommendation': '분석 불가',
        'topStock': null,
        'analysis': '해당 테마의 종목이 없습니다.',
      };
    }

    // 임시 분석 로직 (실제로는 더 복잡한 분석 필요)
    final scores = stocks.map((stock) => getMovingAverageAnalysis(stock['symbol']));
    final avgConfidence = scores.map((s) => s['confidence'] as int).reduce((a, b) => a + b) / scores.length;
    
    return {
      'theme': theme,
      'score': avgConfidence.round(),
      'recommendation': avgConfidence > 70 ? '매수' : avgConfidence > 50 ? '관망' : '매도',
      'topStock': stocks.first,
      'analysis': '이평선 분석 결과 ${avgConfidence.round()}점으로 ${avgConfidence > 70 ? '투자 적합' : '투자 주의'}합니다.',
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  // 모든 테마 분석 결과 가져오기
  static List<Map<String, dynamic>> getAllThemeAnalysis() {
    return getThemes().map((theme) => getThemeAnalysis(theme)).toList();
  }
}