import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/stock.dart';
import '../models/news.dart';
import 'cache_service.dart';
import 'http_client.dart';

class FMPService {
  // 환경변수에서 API 키 가져오기 (없으면 기본값 사용)
  static String get _apiKey {
    const envKey = String.fromEnvironment('FMP_API_KEY');
    return envKey;
  }
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';

  // Finnhub API (Fallback)
  static const String _finnhubApiKey = String.fromEnvironment('FINNHUB_API_KEY');
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
      final searchRes = await getWithRetry(searchUrl);

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
            final quoteRes = await getWithRetry(quoteUrl);

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
      final response = await getWithRetry(searchUrl);
      
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
      final quoteRes = await getWithRetry(quoteUrl);
      
      if (quoteRes.statusCode != 200) return null;
      final quote = json.decode(quoteRes.body);
      
      if (quote['c'] == 0 && quote['pc'] == 0) return null; // 데이터 없음

      // 2. Profile (Name, MarketCap)
      final profileUrl = Uri.parse('$_finnhubBaseUrl/stock/profile2?symbol=$symbol&token=$_finnhubApiKey');
      final profileRes = await getWithRetry(profileUrl);
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
      
      final response = await getWithRetry(quoteUrl);

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
      
      final response = await getWithRetry(newsUrl);

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
    try {
      debugPrint('🤖 [US-RECOMMEND] AI 추천 주식 조회 시작');

      const apiUrl = 'https://stockwiki.vercel.app/api/us-recommend';
      final res = await getWithRetry(Uri.parse(apiUrl));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final List<dynamic> items = body['data'] ?? [];

        final recommendations = items.map<StockRecommendation>((item) {
          final stock = Stock.fromJson(item);
          return StockRecommendation(
            stock: stock,
            score: (item['score'] as num?)?.toDouble() ?? 0,
            reasons: List<String>.from(item['reasons'] ?? []),
            action: item['action'] ?? 'Hold',
          );
        }).toList();

        recommendations.sort((a, b) => b.score.compareTo(a.score));
        return recommendations.take(limit).toList();
      }
      
      debugPrint('⚠️ [US-RECOMMEND] API 응답 실패');
      return [];

    } catch (e) {
      debugPrint('💥 [US-RECOMMEND] 오류: $e');
      return [];
    }
  }

  // 시총 최소 기준: $100억 (USD) 이상 대형주만
  static const double _minMarketCapUsd = 10000000000;

  /// AI 점수 계산 (0-100점) — 이평선 중심
  static double _calculateAIScore(Stock stock) {
    final price = stock.price ?? 0;
    final ma50 = stock.ma50 ?? 0;
    final ma200 = stock.ma200 ?? 0;
    final changePercent = stock.changePercent ?? 0;
    final volume = stock.volume ?? 0;

    double score = 30.0; // 기본 점수

    // ① 이평선 신호 (최대 50점)
    if (ma50 > 0 && ma200 > 0) {
      if (price > ma50 && price > ma200 && ma50 > ma200) {
        score += 50; // 골든크로스 + 가격 이평선 위 — 강세
      } else if (price > ma50 && price > ma200) {
        score += 38;
      } else if (price > ma50 && ma50 > ma200) {
        score += 30;
      } else if (price > ma50) {
        score += 20;
      } else if (price < ma50 && price < ma200) {
        score -= 15; // 데드크로스 구간 — 약세
      }
    } else if (ma50 > 0) {
      score += (price > ma50) ? 20 : -10;
    }

    // ② 모멘텀 (최대 20점)
    if (changePercent >= 3)       score += 20;
    else if (changePercent >= 1)  score += 12;
    else if (changePercent >= 0)  score += 5;
    else if (changePercent >= -2) score -= 5;
    else                          score -= 15;

    // ③ 거래량 (최대 15점)
    if (volume > 10000000)      score += 15;
    else if (volume > 5000000)  score += 10;
    else if (volume > 1000000)  score += 5;

    // ④ 52주 고가 근접 여부 (최대 10점)
    final yearHigh = stock.yearHigh ?? 0;
    if (yearHigh > 0 && price > 0) {
      final ratio = price / yearHigh;
      if (ratio >= 0.95) score += 10; // 52주 고가 95% 이상
      else if (ratio >= 0.85) score += 5;
    }

    return score.clamp(0, 100);
  }

  /// 추천 이유 생성
  static List<String> _generateReasons(Stock stock) {
    final price = stock.price ?? 0;
    final ma50 = stock.ma50 ?? 0;
    final ma200 = stock.ma200 ?? 0;
    final changePercent = stock.changePercent ?? 0;
    final volume = stock.volume ?? 0;
    final yearHigh = stock.yearHigh ?? 0;
    final reasons = <String>[];

    // 이평선 신호
    if (ma50 > 0 && ma200 > 0) {
      if (price > ma50 && price > ma200 && ma50 > ma200) {
        reasons.add('골든크로스 + 현재가 MA50·MA200 상회 — 강한 상승 추세');
      } else if (price > ma50 && price > ma200) {
        reasons.add('현재가 MA50·MA200 상회 — 중장기 상승 구간');
      } else if (price > ma50) {
        reasons.add('현재가 MA50 상회 — 단기 상승 모멘텀');
      }
    }

    // 모멘텀
    if (changePercent >= 3) {
      reasons.add('오늘 +${changePercent.toStringAsFixed(2)}% 강한 상승 모멘텀');
    } else if (changePercent >= 1) {
      reasons.add('오늘 +${changePercent.toStringAsFixed(2)}% 안정적 상승');
    }

    // 거래량
    if (volume > 10000000) {
      reasons.add('거래량 ${(volume / 1000000).toStringAsFixed(0)}M — 유동성 우수');
    } else if (volume > 5000000) {
      reasons.add('거래량 ${(volume / 1000000).toStringAsFixed(0)}M — 활발한 매수세');
    }

    // 52주 고가 근접
    if (yearHigh > 0 && price / yearHigh >= 0.95) {
      reasons.add('52주 고가(${yearHigh.toStringAsFixed(0)}) 근접 — 강한 상승 흐름');
    }

    if (reasons.isEmpty) reasons.add('시장 주도 대형주 — 이평선 기준 관심 종목');
    return reasons;
  }

  /// 액션 결정: 이평선 기반
  static String _determineAction(Stock stock, double score) {
    final price = stock.price ?? 0;
    final ma50 = stock.ma50 ?? 0;
    final ma200 = stock.ma200 ?? 0;
    final marketCap = (stock.marketCap ?? 0).toDouble();

    // 시총 $100억 미만 제외
    if (marketCap < _minMarketCapUsd) return 'Hold';

    // 이평선 데이터 있을 때: 가격이 MA50 위에 있어야 최소 조건
    if (ma50 > 0 && price < ma50) return 'Hold';

    if (score >= 65) return 'Buy';
    if (score >= 50) return 'Buy';
    return 'Hold';
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
      
      final quoteRes = await getWithRetry(quoteUrl);
      
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
      final response = await getWithRetry(url);
      
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
      
      final response = await getWithRetry(url);
      
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

  /// Yahoo Finance 이력 데이터 조회 (Proxy Rotation)
  static Future<List<Map<String, dynamic>>> _fetchHistoricalYahoo(String symbol) async {
    final proxies = [
      (url) => 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      (url) => 'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      (url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
    ];

    final range = '1y';
    final interval = '1d';
    final yahooUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=$range&interval=$interval';

    for (var i = 0; i < proxies.length; i++) {
      try {
        debugLog += 'Try Yahoo (Proxy ${i + 1})... ';
        final proxyUrl = Uri.parse(proxies[i](yahooUrl));
        final response = await getWithRetry(proxyUrl);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Yahoo 응답 구조 확인 (codetabs 등은 감싸서 줄 수도 있음에 유의)
          // 보통 Proxy는 body를 그대로 전달함.
          
          Map<String, dynamic> result;
          if (data['chart'] != null) {
            result = data['chart']['result'][0];
          } else {
             // 데이터 구조가 다를 경우 (Error or unexpected format)
             debugLog += 'Format Err\n';
             continue;
          }

          final timestamp = result['timestamp'] as List;
          final quote = result['indicators']['quote'][0];
          final closes = quote['close'] as List;
          
          List<Map<String, dynamic>> results = [];
          for (int j = 0; j < timestamp.length; j++) {
            if (closes[j] == null) continue;
            
            final dateObj = DateTime.fromMillisecondsSinceEpoch(timestamp[j] * 1000);
            results.add({
              'date': "${dateObj.year}-${dateObj.month.toString().padLeft(2,'0')}-${dateObj.day.toString().padLeft(2,'0')}",
              'close': (closes[j] as num).toDouble(),
              'volume': 0,
            });
          }
          debugLog += 'OK (${results.length})\n';
          return results.reversed.toList();
        }
        debugLog += 'Fail (${response.statusCode})\n';
      } catch (e) {
        debugLog += 'Err\n'; // 상세 에러는 너무 길어질 수 있으므로 줄임
      }
    }
    return [];
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
