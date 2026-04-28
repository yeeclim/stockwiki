import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/news.dart';

class UsStockNewsService {
  static const String _fmpApiKey = String.fromEnvironment('FMP_API_KEY');
  static const String _fmpBaseUrl = 'https://financialmodelingprep.com/api/v3';

  // Finnhub API (무료, CORS 지원)
  static const String _finnhubApiKey = String.fromEnvironment('FINNHUB_API_KEY');
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';

  /// 주식 관련 뉴스 조회 (서버사이드 news-search API 사용, API 키 불필요)
  static Future<List<News>> fetchStockNews(String symbol, {String? stockName, int limit = 10}) async {
    final keyword = stockName ?? symbol;
    return await searchNewsByKeyword(keyword, limit: limit);
  }

  /// 여러 주식 관련 뉴스 조회
  static Future<List<News>> fetchMultipleStockNews(List<String> symbols, {int limit = 20}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tickers = symbols.join(',');
      final newsUrl = Uri.parse(
        '$_fmpBaseUrl/stock_news?tickers=$tickers&limit=$limit&apikey=$_fmpApiKey&t=$timestamp',
      );
      
      final response = await http.get(newsUrl, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      if (data is List) {
        return data.map((item) {
          final news = News.fromJson(item);
          return News(
            title: news.title,
            description: news.description,
            link: news.link,
            source: news.source,
            publishedAt: news.publishedAt,
            sentiment: _analyzeSentiment('${news.title} ${news.description}'),
          );
        }).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 키워드 기반 뉴스 검색 (백엔드 프록시 사용)
  static Future<List<News>> searchNewsByKeyword(String keyword, {int limit = 20}) async {
    try {
      final baseUrl = Uri.base.origin;
      final encoded = Uri.encodeQueryComponent(keyword.trim());
      final uri = Uri.parse('$baseUrl/api/news-search?keyword=$encoded&lang=en&limit=$limit');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        if (jsonData['success'] == true) {
          final results = jsonData['results'] as List<dynamic>? ?? [];
          return results.map<News>((item) => News(
            title: item['title']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            link: item['link']?.toString() ?? '',
            publishedAt: item['publishedAt']?.toString() ?? '',
            source: item['source']?.toString() ?? 'News',
          )).take(limit).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// 주식 시장 전체 뉴스 조회
  static Future<List<News>> fetchMarketNews({int limit = 20}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newsUrl = Uri.parse(
        '$_fmpBaseUrl/stock_news?limit=$limit&apikey=$_fmpApiKey&t=$timestamp',
      );
      
      final response = await http.get(newsUrl, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });

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
  /// 텍스트 감정 분석 (키워드 기반)
  static String _analyzeSentiment(String text) {
    if (text.isEmpty) return 'Neutral';
    final lowerText = text.toLowerCase();
    
    // 긍정 키워드
    final positiveKeywords = [
      'surge', 'jump', 'rise', 'gain', 'climb', 'soar', 'profit', 'beat', 
      'buy', 'upgrade', 'growth', 'record', 'bull', 'positive', 'high', 
      'strong', 'success', 'deal', 'agreement', 'launch', 'win', 'rally'
    ];
    
    // 부정 키워드
    final negativeKeywords = [
      'plunge', 'drop', 'fall', 'decline', 'tumble', 'loss', 'miss', 
      'sell', 'downgrade', 'crisis', 'warn', 'bear', 'negative', 'crash', 
      'fail', 'risk', 'problem', 'concern', 'weak', 'low', 'down'
    ];
    
    int score = 0;
    
    for (final word in positiveKeywords) {
      if (lowerText.contains(word)) score++;
    }
    
    for (final word in negativeKeywords) {
      if (lowerText.contains(word)) score--;
    }
    
    if (score > 0) return 'Positive';
    if (score < 0) return 'Negative';
    return 'Neutral';
  }
}
