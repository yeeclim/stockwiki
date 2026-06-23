import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../models/news.dart';
import 'cache_service.dart';
import 'http_client.dart';

class FMPService {
  // ETF 포함 여부에 따른 exchange 목록
  static const _stockExchanges = {'NASDAQ', 'NYSE', 'AMEX'};
  static const _etfExchanges = {
    'NASDAQ',
    'NYSE',
    'AMEX',
    'ETF',
    'BATS',
    'ARCA'
  };

  /// 키워드 기반 검색 (주식 전용, NASDAQ/NYSE/AMEX 필터)
  static Future<List<Stock>> fetchStocks(String keyword) =>
      _fmpSearch(keyword, _stockExchanges, includeEtf: false);

  /// 키워드 기반 검색 (ETF/레버리지 포함, 거래소 필터 확대)
  static Future<List<Stock>> fetchAll(String keyword) =>
      _fmpSearch(keyword, _etfExchanges, includeEtf: true);

  static Future<List<Stock>> _fmpSearch(
    String keyword,
    Set<String> allowedExchanges, {
    required bool includeEtf,
  }) async {
    final cacheKey = 'fmp_search_${includeEtf ? 'all' : 'stock'}_$keyword';
    final cachedData = await CacheService.get(cacheKey);
    if (cachedData != null) {
      final List<dynamic> list = cachedData;
      return list.map((e) => Stock.fromJson(e)).toList();
    }

    try {
      debugPrint('🔍 [FMP] 검색 시작: $keyword (ETF포함=$includeEtf)');
      final limit = includeEtf ? 20 : 10;
      final searchData = await callProxy('fmp', '/search',
          params: {'query': keyword, 'limit': '$limit'});

      if (searchData is List && searchData.isNotEmpty) {
        List<String> symbols = searchData
            .where((e) {
              final ex = e['exchangeShortName'] as String? ?? '';
              return allowedExchanges.contains(ex);
            })
            .map<String>((e) => e['symbol'] as String)
            .toList();

        if (symbols.isNotEmpty) {
          final quoteData =
              await callProxy('fmp', '/quote/${symbols.join(',')}');
          if (quoteData is List) {
            await CacheService.set(cacheKey, quoteData,
                expiration: const Duration(minutes: 30));
            return quoteData
                .map<Stock>((item) => Stock.fromJson(item))
                .toList();
          }
        }
      }

      debugPrint('⚠️ [FMP] 검색 실패, Finnhub Fallback 시도');
      return await _fetchStocksFinnhub(keyword, includeEtf: includeEtf);
    } catch (e) {
      debugPrint('💥 [FMP] 검색 오류: $e');
      return await _fetchStocksFinnhub(keyword, includeEtf: includeEtf);
    }
  }

  /// Finnhub 검색 Fallback
  static Future<List<Stock>> _fetchStocksFinnhub(String keyword,
      {bool includeEtf = false}) async {
    try {
      final data =
          await callProxy('finnhub', '/search', params: {'q': keyword});
      if (data == null) return [];
      final results = data['result'] as List<dynamic>?;

      if (results == null || results.isEmpty) return [];

      // ETF 포함 여부에 따라 type 필터 조정
      final allowedTypes =
          includeEtf ? {'Common Stock', 'ETF', 'ETP'} : {'Common Stock'};
      final symbols = results
          .take(5)
          .where((item) =>
              allowedTypes.contains(item['type']) &&
              !item['symbol'].contains('.'))
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
  static Future<Map<String, dynamic>?> _fetchStockDetailFinnhub(
      String symbol) async {
    try {
      // 1. Quote (Price)
      final quote =
          await callProxy('finnhub', '/quote', params: {'symbol': symbol});
      if (quote == null) return null;
      if (quote['c'] == 0 && quote['pc'] == 0) return null; // 데이터 없음

      // 2. Profile (Name, MarketCap)
      final profile = await callProxy('finnhub', '/stock/profile2',
              params: {'symbol': symbol}) ??
          {};

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
      final data = await callProxy('fmp', '/quote/$symbol');
      if (data is List && data.isNotEmpty) {
        final result = data[0] as Map<String, dynamic>;
        await CacheService.set(cacheKey, result,
            expiration: const Duration(minutes: 10));
        return result;
      }
      return await _fetchStockDetailFinnhub(symbol);
    } catch (e) {
      return await _fetchStockDetailFinnhub(symbol);
    }
  }

  /// 주식 관련 뉴스 조회
  static Future<List<News>> fetchStockNews(String symbol) async {
    try {
      final data = await callProxy('fmp', '/stock_news',
          params: {'tickers': symbol, 'limit': '10'});
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
      return 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1mo';
    } catch (e) {
      return null;
    }
  }

  /// AI 추천 주식 목록 가져오기 (상승률, 거래량, 시가총액 기준)
  static Future<List<StockRecommendation>> fetchRecommendedStocks(
      {int limit = 20}) async {
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

  /// Sector별 추천 주식 가져오기
  static Future<List<Stock>> fetchStocksBySector(String sector,
      {int limit = 10}) async {
    try {
      debugPrint('📊 [FMP] Sector별 주식 조회: $sector (limit: $limit)');

      // Sector별 주요 주식 심볼 매핑
      final sectorStocks = {
        'Technology': [
          'AAPL',
          'MSFT',
          'GOOGL',
          'AMZN',
          'NVDA',
          'META',
          'AMD',
          'INTC'
        ],
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

      final symbolList = symbols.take(limit).join(',');
      final quoteData = await callProxy('fmp', '/quote/$symbolList');

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

      // Fallback: Finnhub (개별 조회)
      debugPrint('⚠️ [FMP] Sector 조회 실패, Finnhub Fallback 시도');
      List<Stock> stocks = [];
      for (final symbol in symbols.take(5)) {
        // 상위 5개만
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
  static Future<List<Map<String, dynamic>>> fetchHistoricalPrices(String symbol,
      {String timeseries = '5'}) async {
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
  static Future<List<Map<String, dynamic>>> _fetchHistoricalFMP(
      String symbol) async {
    try {
      debugLog += 'Try FMP... ';
      final data = await callProxy('fmp', '/historical-price-full/$symbol');
      if (data != null && data['historical'] != null) {
        final List<dynamic> historical = data['historical'];
        debugLog += 'OK\n';
        return historical
            .map<Map<String, dynamic>>((e) => {
                  'date': e['date'],
                  'close': (e['close'] as num?)?.toDouble() ?? 0.0,
                  'volume': (e['volume'] as num?)?.toInt() ?? 0,
                })
            .where((e) => (e['close'] as double) > 0)
            .toList();
      }
      debugLog += 'Fail (no data)\n';
      return [];
    } catch (e) {
      debugLog += 'Error ($e)\n';
      return [];
    }
  }

  /// Finnhub 이력 데이터 조회
  static Future<List<Map<String, dynamic>>> _fetchHistoricalFinnhub(
      String symbol) async {
    try {
      debugLog += 'Try Finnhub... ';
      final now = DateTime.now();
      final to = (now.millisecondsSinceEpoch / 1000).round();
      final from =
          (now.subtract(const Duration(days: 365)).millisecondsSinceEpoch /
                  1000)
              .round();

      final data = await callProxy('finnhub', '/stock/candle', params: {
        'symbol': symbol,
        'resolution': 'D',
        'from': '$from',
        'to': '$to',
      });

      if (data != null && data['s'] == 'ok') {
        List<Map<String, dynamic>> results = [];
        final closes = data['c'] as List;
        final times = data['t'] as List;

        for (int i = 0; i < closes.length; i++) {
          final dateObj = DateTime.fromMillisecondsSinceEpoch(times[i] * 1000);
          results.add({
            'date':
                "${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}",
            'close': (closes[i] as num).toDouble(),
            'volume': 0,
          });
        }
        debugLog += 'OK (${results.length})\n';
        return results.reversed.toList();
      }
      debugLog += 'No Data (${data?['s'] ?? 'null'})\n';
      return [];
    } catch (e) {
      debugLog += 'Error ($e)\n';
      return [];
    }
  }

  /// Yahoo Finance 이력 데이터 조회 (Proxy Rotation)
  static Future<List<Map<String, dynamic>>> _fetchHistoricalYahoo(
      String symbol) async {
    final proxies = [
      (url) => 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      (url) =>
          'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      (url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
    ];

    const range = '1y';
    const interval = '1d';
    final yahooUrl =
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=$range&interval=$interval';

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

            final dateObj =
                DateTime.fromMillisecondsSinceEpoch(timestamp[j] * 1000);
            results.add({
              'date':
                  "${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}",
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
