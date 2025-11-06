import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../models/news.dart';

class FMPService {
  static const String _apiKey = '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh'; // 실제 키로 교체
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';
  static const String _corsProxy = 'https://api.codetabs.com/v1/proxy?quest=';

  /// 키워드 기반 검색 후 실시간 가격 정보 추가
  static Future<List<Stock>> fetchStocks(String keyword) async {
    try {
      print('🔍 [FMP] 검색 시작: $keyword');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 웹에서 CORS 문제 해결을 위한 프록시 사용
      final searchUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp');
      
      print('🌐 [FMP] 검색 URL: $searchUrl');
      print('📱 [FMP] 웹 모드: $kIsWeb');
      
      final searchRes = await http.get(searchUrl);
      print('📊 [FMP] 검색 응답 상태: ${searchRes.statusCode}');
      print('📄 [FMP] 검색 응답 본문: ${searchRes.body}');

      if (searchRes.statusCode != 200) {
        print('❌ [FMP] 검색 실패 - 상태 코드: ${searchRes.statusCode}');
        throw Exception('검색 실패: ${searchRes.statusCode}');
      }

      final searchData = json.decode(searchRes.body);
      print('📋 [FMP] 검색 데이터 파싱 완료: ${searchData.runtimeType}');
      
      if (searchData is! List || searchData.isEmpty) {
        print('⚠️ [FMP] 검색 결과가 비어있음');
        return [];
      }

      // 미국 주식만 필터링 (무료 플랜 제한)
      List<String> symbols = searchData
          .where((e) => e['exchangeShortName'] == 'NASDAQ' || 
                       e['exchangeShortName'] == 'NYSE' ||
                       e['exchangeShortName'] == 'AMEX')
          .map<String>((e) => e['symbol'] as String)
          .toList();
      print('🏷️ [FMP] 추출된 심볼들 (미국 주식만): $symbols');
      
      if (symbols.isEmpty) {
        print('⚠️ [FMP] 미국 주식이 없음');
        return [];
      }

      // 심볼 기반으로 실시간 정보 조회
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp');
      
      print('💰 [FMP] 시세 URL: $quoteUrl');
      final quoteRes = await http.get(quoteUrl);
      print('📊 [FMP] 시세 응답 상태: ${quoteRes.statusCode}');
      print('📄 [FMP] 시세 응답 본문: ${quoteRes.body}');

      if (quoteRes.statusCode != 200) {
        print('❌ [FMP] 시세 조회 실패 - 상태 코드: ${quoteRes.statusCode}');
        throw Exception('시세 조회 실패: ${quoteRes.statusCode}');
      }

      final quoteData = json.decode(quoteRes.body);
      print('📋 [FMP] 시세 데이터 파싱 완료: ${quoteData.runtimeType}');
      
      if (quoteData is! List) {
        print('⚠️ [FMP] 시세 데이터가 리스트가 아님');
        return [];
      }

      List<Stock> stocks = quoteData
          .map<Stock>((item) => Stock.fromJson(item))
          .toList();
      
      print('✅ [FMP] 최종 결과: ${stocks.length}개 주식');
      return stocks;
    } catch (e) {
      print('💥 [FMP] 전체 오류: $e');
      print('📚 [FMP] 오류 타입: ${e.runtimeType}');
      return [];
    }
  }

  /// 단일 주식 상세 정보 조회 (차트용)
  static Future<Map<String, dynamic>?> fetchStockDetail(String symbol) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/$symbol?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(quoteUrl);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0];
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 주식 관련 뉴스 조회
  static Future<List<News>> fetchStockNews(String symbol) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newsUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/stock_news?tickers=$symbol&limit=10&apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/stock_news?tickers=$symbol&limit=10&apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(newsUrl);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      if (data is List) {
        return data.map((item) => News.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Yahoo Finance 차트 데이터 가져오기 (대체 방법)
  static Future<String?> getYahooChartUrl(String symbol) async {
    try {
      // Yahoo Finance 차트 이미지 URL 생성
      return 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1mo';
    } catch (e) {
      return null;
    }
  }

  /// AI 추천 주식 목록 가져오기 (상승률, 거래량, 시가총액 기준)
  static Future<List<StockRecommendation>> fetchRecommendedStocks({int limit = 20}) async {
    try {
      print('🤖 [FMP] AI 추천 주식 조회 시작 (limit: $limit)');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 주요 미국 주식 심볼 목록 (S&P 500 상위 종목)
      final majorStocks = [
        'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK.B',
        'UNH', 'JNJ', 'V', 'XOM', 'JPM', 'WMT', 'PG', 'MA', 'CVX', 'LLY',
        'AVGO', 'PEP', 'COST', 'ABBV', 'MRK', 'AMD', 'MCD', 'TMO', 'NFLX'
      ];
      
      // 실시간 시세 조회
      final symbols = majorStocks.join(',');
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/$symbols?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/$symbols?apikey=$_apiKey&t=$timestamp');
      
      print('💰 [FMP] 추천 주식 시세 URL: $quoteUrl');
      final quoteRes = await http.get(quoteUrl);
      
      if (quoteRes.statusCode != 200) {
        print('❌ [FMP] 추천 주식 시세 조회 실패: ${quoteRes.statusCode}');
        return [];
      }

      final quoteData = json.decode(quoteRes.body);
      if (quoteData is! List || quoteData.isEmpty) {
        print('⚠️ [FMP] 추천 주식 데이터가 비어있음');
        return [];
      }

      // Stock 객체로 변환 및 AI 점수 계산
      List<StockRecommendation> recommendations = quoteData
          .where((item) => item['price'] != null && item['changePercent'] != null)
          .map<StockRecommendation>((item) {
            final stock = Stock.fromJson(item);
            final score = _calculateAIScore(stock);
            final reasons = _generateReasons(stock);
            final action = _determineAction(stock, score);
            
            return StockRecommendation(
              stock: stock,
              score: score,
              reasons: reasons,
              action: action,
            );
          })
          .toList();

      // AI 점수 기준으로 정렬
      recommendations.sort((a, b) => b.score.compareTo(a.score));

      print('✅ [FMP] AI 추천 주식: ${recommendations.length}개');
      return recommendations.take(limit).toList();
    } catch (e) {
      print('💥 [FMP] AI 추천 주식 조회 오류: $e');
      return [];
    }
  }

  /// AI 점수 계산 (0-100점)
  static double _calculateAIScore(Stock stock) {
    double score = 50.0; // 기본 점수
    
    // 상승률 점수 (0-30점)
    final changePercent = stock.changePercent ?? 0;
    if (changePercent > 0) {
      score += (changePercent * 2).clamp(0, 30); // 상승률 1%당 2점 (최대 30점)
    } else {
      score += (changePercent * 1.5).clamp(-30, 0); // 하락률 페널티
    }
    
    // 거래량 점수 (0-20점)
    final volume = stock.volume ?? 0;
    if (volume > 10000000) {
      score += 20; // 거래량 1천만 이상
    } else if (volume > 5000000) {
      score += 15; // 거래량 5백만 이상
    } else if (volume > 1000000) {
      score += 10; // 거래량 1백만 이상
    } else if (volume > 500000) {
      score += 5; // 거래량 50만 이상
    }
    
    // 시가총액 점수 (0-20점)
    final marketCap = stock.marketCap ?? 0;
    if (marketCap > 1000000000000) {
      score += 20; // 시가총액 1조 이상
    } else if (marketCap > 500000000000) {
      score += 15; // 시가총액 5천억 이상
    } else if (marketCap > 100000000000) {
      score += 10; // 시가총액 1천억 이상
    }
    
    // 변동성 점수 (0-10점) - 상승률의 절댓값이 적당한 경우
    if (changePercent.abs() > 2 && changePercent.abs() < 10 && changePercent > 0) {
      score += 10; // 적당한 상승 변동성
    }
    
    return score.clamp(0, 100);
  }

  /// 추천 이유 생성
  static List<String> _generateReasons(Stock stock) {
    List<String> reasons = [];
    
    final changePercent = stock.changePercent ?? 0;
    final volume = stock.volume ?? 0;
    final marketCap = stock.marketCap ?? 0;
    
    if (changePercent > 3) {
      reasons.add('강한 상승 모멘텀 (${changePercent.toStringAsFixed(2)}%)');
    } else if (changePercent > 1) {
      reasons.add('안정적 상승 추세 (${changePercent.toStringAsFixed(2)}%)');
    }
    
    if (volume > 10000000) {
      reasons.add('높은 거래량으로 유동성 우수');
    } else if (volume > 5000000) {
      reasons.add('활발한 거래량');
    }
    
    if (marketCap > 1000000000000) {
      reasons.add('대형주로 안정성 높음');
    } else if (marketCap > 500000000000) {
      reasons.add('중대형주로 성장성 우수');
    }
    
    // Sector별 이유
    if (stock.symbol.contains('AAPL') || stock.symbol.contains('MSFT') || 
        stock.symbol.contains('GOOGL') || stock.symbol.contains('NVDA')) {
      reasons.add('기술주 선두주자로 성장 잠재력');
    }
    
    if (reasons.isEmpty) {
      reasons.add('시장 관심도 높은 종목');
    }
    
    return reasons;
  }

  /// 액션 결정 (Buy, Hold, Watch)
  static String _determineAction(Stock stock, double score) {
    final changePercent = stock.changePercent ?? 0;
    
    if (score >= 70 && changePercent > 2) {
      return 'Buy';
    } else if (score >= 50 && changePercent > 0) {
      return 'Hold';
    } else {
      return 'Watch';
    }
  }

  /// Sector별 추천 주식 가져오기
  static Future<List<Stock>> fetchStocksBySector(String sector, {int limit = 10}) async {
    try {
      print('📊 [FMP] Sector별 주식 조회: $sector (limit: $limit)');
      
      // Sector별 주요 주식 심볼 매핑
      final sectorStocks = {
        'Technology': ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'AMD', 'INTC'],
        'Finance': ['JPM', 'BAC', 'WFC', 'GS', 'MS', 'C', 'V', 'MA'],
        'Healthcare': ['UNH', 'JNJ', 'PFE', 'ABBV', 'MRK', 'TMO', 'ABT', 'DHR'],
        'Consumer': ['WMT', 'PG', 'KO', 'PEP', 'MCD', 'NKE', 'SBUX', 'TGT'],
        'Energy': ['XOM', 'CVX', 'COP', 'SLB', 'EOG', 'MPC', 'VLO', 'PSX'],
        'Industrial': ['BA', 'CAT', 'GE', 'HON', 'RTX', 'LMT', 'NOC', 'GD'],
      };
      
      final symbols = sectorStocks[sector] ?? [];
      if (symbols.isEmpty) {
        print('⚠️ [FMP] 알 수 없는 Sector: $sector');
        return [];
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final symbolList = symbols.take(limit).join(',');
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/$symbolList?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/$symbolList?apikey=$_apiKey&t=$timestamp');
      
      final quoteRes = await http.get(quoteUrl);
      
      if (quoteRes.statusCode != 200) {
        return [];
      }

      final quoteData = json.decode(quoteRes.body);
      if (quoteData is! List) {
        return [];
      }

      List<Stock> stocks = quoteData
          .where((item) => item['price'] != null)
          .map<Stock>((item) => Stock.fromJson(item))
          .toList();

      // 상승률 기준 정렬
      stocks.sort((a, b) {
        final aChange = a.changePercent ?? 0;
        final bChange = b.changePercent ?? 0;
        return bChange.compareTo(aChange);
      });

      print('✅ [FMP] Sector별 주식: ${stocks.length}개');
      return stocks;
    } catch (e) {
      print('💥 [FMP] Sector별 주식 조회 오류: $e');
      return [];
    }
  }

  /// 주요 Sector 목록 가져오기
  static List<String> getAvailableSectors() {
    return ['Technology', 'Finance', 'Healthcare', 'Consumer', 'Energy', 'Industrial'];
  }
}

/// AI 추천 주식 모델
class StockRecommendation {
  final Stock stock;
  final double score; // AI 점수 (0-100)
  final List<String> reasons; // 추천 이유
  final String action; // Buy, Hold, Watch

  StockRecommendation({
    required this.stock,
    required this.score,
    required this.reasons,
    required this.action,
  });
}
