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

  /// 미국 주식 관련 뉴스 조회 (Finnhub API 사용 - 무료, CORS 지원)
  static Future<List<News>> fetchStockNews(String symbol, {int limit = 10}) async {
    try {
      debugPrint('📰 [News] 뉴스 조회 시작 (Finnhub): $symbol');
      
      // Finnhub company news API (최근 30일)
      final fromDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
      final toDate = DateTime.now().toIso8601String().split('T')[0];
      
      final newsUrl = Uri.parse(
        '$_finnhubBaseUrl/company-news?symbol=$symbol&from=$fromDate&to=$toDate&token=$_finnhubApiKey'
      );
      
      debugPrint('🌐 [News] 뉴스 URL: $newsUrl');
      
      final response = await http.get(newsUrl);
      debugPrint('📊 [News] 뉴스 응답 상태: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        debugPrint('❌ [News] 뉴스 조회 실패 - 상태 코드: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      debugPrint('📋 [News] 뉴스 데이터 파싱 완료: ${data.runtimeType}');
      
      // Finnhub는 배열로 직접 반환
      if (data is List) {
        if (data.isEmpty) {
          debugPrint('⚠️ [News] 뉴스 리스트가 비어있음');
          return [];
        }
        
        debugPrint('📰 [News] 첫 번째 뉴스 샘플: ${data[0]}');
        
        try {
          final newsList = data
              .take(limit)
              .map((item) {
                try {
                  final datetime = item['datetime'];
                  String publishedAt = '';
                  
                  if (datetime != null) {
                    try {
                      publishedAt = DateTime.fromMillisecondsSinceEpoch(
                        datetime * 1000,
                      ).toIso8601String();
                    } catch (e) {
                      debugPrint('⚠️ [News] datetime 파싱 오류: $e');
                    }
                  }
                  
                  final title = item['headline']?.toString() ?? '';
                  final description = item['summary']?.toString() ?? '';
                  
                  return News(
                    title: title,
                    description: description,
                    link: item['url']?.toString() ?? '',
                    source: item['source']?.toString() ?? '',
                    publishedAt: publishedAt,
                    sentiment: _analyzeSentiment('$title $description'),
                  );
                } catch (e) {
                  debugPrint('⚠️ [News] 개별 뉴스 파싱 오류: $e, item: $item');
                  rethrow;
                }
              })
              .toList();
          debugPrint('✅ [News] 뉴스 ${newsList.length}개 로드 완료');
          return newsList;
        } catch (e) {
          debugPrint('💥 [News] 뉴스 파싱 오류: $e');
          debugPrint('📄 [News] 오류 스택: ${StackTrace.current}');
          return [];
        }
      }
      
      debugPrint('⚠️ [News] 뉴스 데이터가 리스트가 아님: $data');
      return [];
    } catch (e) {
      debugPrint('💥 [News] 뉴스 조회 오류: $e');
      return [];
    }
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
