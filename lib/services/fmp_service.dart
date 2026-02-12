import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/stock.dart';
import '../models/news.dart';
import 'cache_service.dart';

class FMPService {
  // 환경변수에서 API 키 가져오기 (없으면 기본값 사용)
  static String get _apiKey {
    // Flutter 웹에서는 환경변수 접근이 제한적이므로
    // 실제 배포 시에는 서버 사이드에서 처리하거나
    // Vercel 환경변수 등을 활용해야 함
    const envKey = String.fromEnvironment('FMP_API_KEY');
    return envKey.isNotEmpty ? envKey : '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh';
  }
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';
  // CORS Proxy 제거 (FMP API 직접 호출 시도)
  // static const String _corsProxy = 'https://api.codetabs.com/v1/proxy?quest=';
  
  // Finnhub API (Fallback)
  static const String _finnhubApiKey = 'd3ecam1r01qrd38tq1c0d3ecam1r01qrd38tq1cg';
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';

  /// 키워드 기반 검색 후 실시간 가격 정보 추가
  static Future<List<Stock>> fetchStocks(String keyword) async {
    // 1. 캐시 확인
    final cacheKey = 'fmp_search_$keyword';
    final cachedData = await CacheService.get(cacheKey);
    if (cachedData != null) {
      final List<dynamic> list = cachedData;
      return list.map((e) => Stock.fromJson(e)).toList();
    }

    try {
      debugPrint('🔍 [FMP] 검색 시작: $keyword');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 1. FMP 검색 시도
      final searchUrl = Uri.parse('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp');
      final searchRes = await http.get(searchUrl);

      if (searchRes.statusCode == 200) {
        final searchData = json.decode(searchRes.body);
        
        if (searchData is List && searchData.isNotEmpty) {
           // 미국 주식만 필터링
          List<String> symbols = searchData
              .where((e) => e['exchangeShortName'] == 'NASDAQ' || 
                          e['exchangeShortName'] == 'NYSE' ||
                          e['exchangeShortName'] == 'AMEX')
              .map<String>((e) => e['symbol'] as String)
              .toList();
          
          if (symbols.isNotEmpty) {
            // 심볼 기반으로 실시간 정보 조회
            final quoteUrl = Uri.parse('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp');
            final quoteRes = await http.get(quoteUrl);

            if (quoteRes.statusCode == 200) {
              final quoteData = json.decode(quoteRes.body);
              if (quoteData is List) {
                // 2. 캐시 저장 (30분)
                await CacheService.set(cacheKey, quoteData, expiration: const Duration(minutes: 30));
                return quoteData.map<Stock>((item) => Stock.fromJson(item)).toList();
              }
            }
          }
        }
      }
      
      debugPrint('⚠️ [FMP] 검색 실패 또는 결과 없음, Finnhub Fallback 시도');
      return await _fetchStocksFinnhub(keyword);
      
    } catch (e) {
      debugPrint('💥 [FMP] 검색 오류: $e, Finnhub Fallback 시도');
      return await _fetchStocksFinnhub(keyword);
    }
  }

  /// Finnhub 검색 Fallback
  static Future<List<Stock>> _fetchStocksFinnhub(String keyword) async {
    try {
      final searchUrl = Uri.parse('$_finnhubBaseUrl/search?q=$keyword&token=$_finnhubApiKey');
      final response = await http.get(searchUrl);
      
      if (response.statusCode != 200) return [];
      
      final data = json.decode(response.body);
      final results = data['result'] as List<dynamic>?;
      
      if (results == null || results.isEmpty) return [];
      
      // 상위 5개만 상세 조회 (Rate Limit 고려)
      final symbols = results
          .take(5)
          .where((item) => item['type'] == 'Common Stock' && !item['symbol'].contains('.'))
          .map((item) => item['symbol'] as String)
          .toList();
          
      List<Stock> stocks = [];
      for (final symbol in symbols) {
        final detail = await _fetchStockDetailFinnhub(symbol);
        if (detail != null) {
          stocks.add(Stock.fromJson(detail));
        }
      }
      return stocks;
    } catch (e) {
      debugPrint('💥 [Finnhub] 검색 오류: $e');
      return [];
    }
  }

  /// Finnhub 단일 주식 상세 조회
  static Future<Map<String, dynamic>?> _fetchStockDetailFinnhub(String symbol) async {
    try {
      // 1. Quote (Price)
      final quoteUrl = Uri.parse('$_finnhubBaseUrl/quote?symbol=$symbol&token=$_finnhubApiKey');
      final quoteRes = await http.get(quoteUrl);
      
      if (quoteRes.statusCode != 200) return null;
      final quote = json.decode(quoteRes.body);
      
      if (quote['c'] == 0 && quote['pc'] == 0) return null; // 데이터 없음

      // 2. Profile (Name, MarketCap)
      final profileUrl = Uri.parse('$_finnhubBaseUrl/stock/profile2?symbol=$symbol&token=$_finnhubApiKey');
      final profileRes = await http.get(profileUrl);
      final profile = (profileRes.statusCode == 200) ? json.decode(profileRes.body) : {};

      return {
        'symbol': symbol,
        'name': profile['name'] ?? symbol,
        'price': quote['c']?.toDouble(),
        'change': quote['d']?.toDouble(),
        'changePercent': quote['dp']?.toDouble(),
        'volume': 0, // Finnhub 무료 플랜은 거래량 제공 제한적
        'marketCap': (profile['marketCapitalization'] != null) 
            ? (profile['marketCapitalization'] * 1000000).toInt() 
            : 0,
        'exchange': profile['exchange'] ?? 'US',
      };
    } catch (e) {
      return null;
    }
  }

  /// 단일 주식 상세 정보 조회 (차트용)
  static Future<Map<String, dynamic>?> fetchStockDetail(String symbol) async {
    // 1. 캐시 확인
    final cacheKey = 'fmp_stock_detail_$symbol';
    final cachedData = await CacheService.get(cacheKey);
    if (cachedData != null) {
      return cachedData as Map<String, dynamic>;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final quoteUrl = Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(quoteUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final result = data[0] as Map<String, dynamic>;
          // 2. 캐시 저장 (10분)
          await CacheService.set(cacheKey, result, expiration: const Duration(minutes: 10));
          return result;
        }
      }
      
      // Fallback
      return await _fetchStockDetailFinnhub(symbol);
    } catch (e) {
      return await _fetchStockDetailFinnhub(symbol);
    }
  }

  /// 주식 관련 뉴스 조회
  static Future<List<News>> fetchStockNews(String symbol) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newsUrl = Uri.parse('$_baseUrl/stock_news?tickers=$symbol&limit=10&apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(newsUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => News.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Yahoo Finance 차트 데이터 가져오기 (대체 방법)
  static Future<String?> getYahooChartUrl(String symbol) async {
    try {
      return 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1mo';
    } catch (e) {
      return null;
    }
  }

  /// AI 추천 주식 목록 가져오기 (상승률, 거래량, 시가총액 기준)
  static Future<List<StockRecommendation>> fetchRecommendedStocks({int limit = 20}) async {
    // 주요 미국 주식 심볼 목록 (S&P 500 상위 종목)
    final majorStocks = [
      'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK.B',
      'UNH', 'JNJ', 'PFE', 'XOM', 'JPM', 'WMT', 'PG', 'MA', 'CVX', 'LLY',
      'AVGO', 'PEP', 'COST', 'ABBV', 'MRK', 'AMD', 'MCD', 'TMO', 'NFLX'
    ];

    try {
      debugPrint('🤖 [FMP] AI 추천 주식 조회 시작 (limit: $limit)');
      
      // 1. 캐시 확인
      final cacheKey = 'fmp_recommendations';
      final cachedData = await CacheService.get(cacheKey);
      
      if (cachedData != null) {
        final List<dynamic> quoteData = cachedData;
        
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
             .where((rec) => rec.action == 'Buy') 
             .toList();

        recommendations.sort((a, b) => b.score.compareTo(a.score));
        return recommendations.take(limit).toList();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 실시간 시세 조회
      final symbols = majorStocks.join(',');
      final quoteUrl = Uri.parse('$_baseUrl/quote/$symbols?apikey=$_apiKey&t=$timestamp');
      
      final quoteRes = await http.get(quoteUrl);
      
      if (quoteRes.statusCode == 200) {
        final quoteData = json.decode(quoteRes.body);
        if (quoteData is List && quoteData.isNotEmpty) {
           // 2. 캐시 저장 (1시간) - 추천 정보는 자주 안 변해도 됨
           await CacheService.set(cacheKey, quoteData, expiration: const Duration(hours: 1));
           
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
              .where((rec) => rec.action == 'Buy') // Hold, Watch 제거
              .toList();

          recommendations.sort((a, b) => b.score.compareTo(a.score));
          return recommendations.take(limit).toList();
        }
      }

      // Fallback: Finnhub (상위 5개만 조회하여 추천)
      debugPrint('⚠️ [FMP] 추천 조회 실패, Finnhub Fallback 시도');
      List<StockRecommendation> recommendations = [];
      for (var symbol in majorStocks.take(5)) {
        final detail = await _fetchStockDetailFinnhub(symbol);
        if (detail != null) {
          final stock = Stock.fromJson(detail);
          final score = _calculateAIScore(stock); // 거래량 누락으로 점수는 낮을 수 있음
          recommendations.add(StockRecommendation(
            stock: stock,
            score: score,
            reasons: ['시장 주도 대형주 (데이터 대체)'], 
            action: 'Hold',
          ));
        }
      }
      return recommendations;

    } catch (e) {
      debugPrint('💥 [FMP] AI 추천 주식 조회 오류: $e');
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
    
    // 점수가 높으면(60점 이상) 상승률이 낮아도 매수 추천
    if (score >= 60) {
      return 'Buy';
    } 
    // 점수가 준수(50점 이상)하고 상승세가 뚜렷하면 매수 추천
    else if (score >= 50 && changePercent > 1.0) {
      return 'Buy';
    }
    // 그 외에는 관망 (API에서 필터링됨)
    else {
      return 'Hold';
    }
  }

  /// Sector별 추천 주식 가져오기
  static Future<List<Stock>> fetchStocksBySector(String sector, {int limit = 10}) async {
    try {
      debugPrint('📊 [FMP] Sector별 주식 조회: $sector (limit: $limit)');
      
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
        return [];
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final symbolList = symbols.take(limit).join(',');
      final quoteUrl = Uri.parse('$_baseUrl/quote/$symbolList?apikey=$_apiKey&t=$timestamp');
      
      final quoteRes = await http.get(quoteUrl);
      
      if (quoteRes.statusCode == 200) {
        final quoteData = json.decode(quoteRes.body);
        if (quoteData is List) {
          List<Stock> stocks = quoteData
              .where((item) => item['price'] != null)
              .map<Stock>((item) => Stock.fromJson(item))
              .toList();

          stocks.sort((a, b) {
            final aChange = a.changePercent ?? 0;
            final bChange = b.changePercent ?? 0;
            return bChange.compareTo(aChange);
          });
          return stocks;
        }
      }

      // Fallback: Finnhub (개별 조회)
      debugPrint('⚠️ [FMP] Sector 조회 실패, Finnhub Fallback 시도');
      List<Stock> stocks = [];
      for (final symbol in symbols.take(5)) { // 상위 5개만
        final detail = await _fetchStockDetailFinnhub(symbol);
        if (detail != null) {
          stocks.add(Stock.fromJson(detail));
        }
      }
      return stocks;

    } catch (e) {
      return [];
    }
  }

  static String debugLog = '';

  /// 주식 이력 데이터 조회 (차트용) - 다중 소스 Fallback 적용
  static Future<List<Map<String, dynamic>>> fetchHistoricalPrices(String symbol, {String timeseries = '5'}) async {
    List<Map<String, dynamic>> data = [];
    debugLog = 'Start fetching $symbol... \n';
    
    // 1. FMP 시도
    data = await _fetchHistoricalFMP(symbol);
    if (data.isNotEmpty) {
      debugLog += 'Success: FMP\n';
      return data;
    }

    // 2. Finnhub 시도
    data = await _fetchHistoricalFinnhub(symbol);
    if (data.isNotEmpty) {
      debugLog += 'Success: Finnhub\n';
      return data;
    }

    // 3. Yahoo Finance 시도 (Proxy 사용)
    data = await _fetchHistoricalYahoo(symbol);
    if (data.isNotEmpty) {
      debugLog += 'Success: Yahoo\n';
      return data;
    }
    
    debugLog += 'All failed.';
    return data;
  }

  /// FMP 이력 데이터 조회
  static Future<List<Map<String, dynamic>>> _fetchHistoricalFMP(String symbol) async {
    try {
      final url = Uri.parse('$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey');
      debugLog += 'Try FMP... ';
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['historical'] != null) {
          final List<dynamic> historical = data['historical'];
          debugLog += 'OK\n';
          return historical.map<Map<String, dynamic>>((e) => {
            'date': e['date'],
            'close': (e['close'] as num).toDouble(),
            'volume': (e['volume'] as num).toInt(),
          }).toList();
        }
      }
      debugLog += 'Fail (${response.statusCode})\n';
      return [];
    } catch (e) {
      debugLog += 'Error ($e)\n';
      return [];
    }
  }

  /// Finnhub 이력 데이터 조회
  static Future<List<Map<String, dynamic>>> _fetchHistoricalFinnhub(String symbol) async {
    try {
      debugLog += 'Try Finnhub... ';
      final now = DateTime.now();
      final to = (now.millisecondsSinceEpoch / 1000).round();
      final from = (now.subtract(const Duration(days: 365)).millisecondsSinceEpoch / 1000).round();
      
      final url = Uri.parse(
          '$_finnhubBaseUrl/stock/candle?symbol=$symbol&resolution=D&from=$from&to=$to&token=$_finnhubApiKey');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['s'] == 'ok') {
          List<Map<String, dynamic>> results = [];
          final closes = data['c'] as List;
          final times = data['t'] as List; 
          
          for (int i = 0; i < closes.length; i++) {
            final dateObj = DateTime.fromMillisecondsSinceEpoch(times[i] * 1000);
            results.add({
              'date': "${dateObj.year}-${dateObj.month.toString().padLeft(2,'0')}-${dateObj.day.toString().padLeft(2,'0')}",
              'close': (closes[i] as num).toDouble(),
              'volume': 0, 
            });
          }
          debugLog += 'OK (${results.length})\n';
          return results.reversed.toList();
        }
        debugLog += 'No Data (${data['s']})\n';
      } else {
        debugLog += 'Fail (${response.statusCode})\n';
      }
      return [];
    } catch (e) {
      debugLog += 'Error ($e)\n';
      return [];
    }
  }

  /// Yahoo Finance 이력 데이터 조회 (Proxy)
  static Future<List<Map<String, dynamic>>> _fetchHistoricalYahoo(String symbol) async {
    try {
      debugLog += 'Try Yahoo... ';
      final range = '1y';
      final interval = '1d';
      final yahooUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=$range&interval=$interval';
      // Switch proxy to allorigins.win
      final proxyUrl = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(yahooUrl)}');
      
      final response = await http.get(proxyUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result'][0];
        final timestamp = result['timestamp'] as List;
        final quote = result['indicators']['quote'][0];
        final closes = quote['close'] as List;
        
        List<Map<String, dynamic>> results = [];
        for (int i = 0; i < timestamp.length; i++) {
          if (closes[i] == null) continue;
          
          final dateObj = DateTime.fromMillisecondsSinceEpoch(timestamp[i] * 1000);
          results.add({
            'date': "${dateObj.year}-${dateObj.month.toString().padLeft(2,'0')}-${dateObj.day.toString().padLeft(2,'0')}",
            'close': (closes[i] as num).toDouble(),
            'volume': 0,
          });
        }
        debugLog += 'OK (${results.length})\n';
        return results.reversed.toList();
      }
      debugLog += 'Fail (${response.statusCode})\n';
      return [];
    } catch (e) {
      debugLog += 'Error ($e)\n';
      return [];
    }
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
