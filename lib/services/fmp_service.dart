import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import 'cache_service.dart';
import 'http_client.dart';

/// 미국 종목 상세 시세 + AI 추천 목록.
///
/// 이름과 달리 FMP 는 거의 쓰지 않는다. FMP v3 API 가 2025-08-31 자로 폐기돼
/// 전 경로가 Legacy Endpoint 오류를 반환하므로, 상세 시세는 Finnhub 로 넘어가고
/// 추천 목록은 /api/us-recommend 가 채운다. 검색·차트·뉴스도 각각
/// /api/us-stock-search, /api/utils?type=us-candles, /api/news-search 로
/// 옮겨 갔고, 여기 남아 있던 그 경로들은 호출부가 없어 제거했다.
class FMPService {
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
