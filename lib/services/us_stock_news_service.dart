import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/news.dart';

class UsStockNewsService {
  static const String _fmpApiKey = '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh';
  static const String _fmpBaseUrl = 'https://financialmodelingprep.com/api/v3';
  static const String _corsProxy = 'https://api.codetabs.com/v1/proxy?quest=';
  
  // Finnhub API (무료, CORS 지원)
  static const String _finnhubApiKey = 'd3ecam1r01qrd38tq1c0d3ecam1r01qrd38tq1cg';
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';
  
  // Alpha Vantage API (무료, 안정적)
  static const String _alphaVantageApiKey = 'demo'; // 실제 키로 교체 필요
  static const String _alphaVantageBaseUrl = 'https://www.alphavantage.co/query';

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
                  
                  return News(
                    title: item['headline']?.toString() ?? '',
                    description: item['summary']?.toString() ?? '',
                    link: item['url']?.toString() ?? '',
                    source: item['source']?.toString() ?? '',
                    publishedAt: publishedAt,
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
        return data.map((item) => News.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 키워드 기반 뉴스 검색 (다양한 뉴스 API 사용)
  static Future<List<News>> searchNewsByKeyword(String keyword, {int limit = 20}) async {
    List<News> allNews = [];

    try {
      // 1. NewsData.io API
      final newsdataNews = await _fetchFromNewsData(keyword, limit: limit ~/ 3);
      allNews.addAll(newsdataNews);

      // 2. GNews API
      final gnewsNews = await _fetchFromGNews(keyword, limit: limit ~/ 3);
      allNews.addAll(gnewsNews);

      // 3. MediaStack API
      final mediastackNews = await _fetchFromMediaStack(keyword, limit: limit ~/ 3);
      allNews.addAll(mediastackNews);

      // 중복 제거 (제목 기준)
      final uniqueNews = <String, News>{};
      for (final news in allNews) {
        final title = news.title.toLowerCase().trim();
        if (!uniqueNews.containsKey(title)) {
          uniqueNews[title] = news;
        }
      }

      return uniqueNews.values.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// NewsData.io API 호출
  static Future<List<News>> _fetchFromNewsData(String keyword, {int limit = 10}) async {
    try {
      final uri = Uri.parse(
        'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$keyword&language=en&category=business&size=$limit',
      );
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News(
          title: item['title']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
          link: item['link']?.toString() ?? '',
          publishedAt: item['pubDate']?.toString() ?? '',
          source: item['source_id']?.toString() ?? 'NewsData.io',
        )).toList();
      }
    } catch (e) {
      // NewsData.io 오류
    }
    return [];
  }

  /// GNews API 호출
  static Future<List<News>> _fetchFromGNews(String keyword, {int limit = 10}) async {
    try {
      final uri = Uri.parse(
        'https://gnews.io/api/v4/search?token=6c6fdfc93ae9225b3bd4210978798fc1&q=$keyword&lang=en&country=us&max=$limit',
      );
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['articles'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News(
          title: item['title']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
          link: item['url']?.toString() ?? '',
          publishedAt: item['publishedAt']?.toString() ?? '',
          source: item['source']['name']?.toString() ?? 'GNews',
        )).toList();
      }
    } catch (e) {
      // GNews 오류
    }
    return [];
  }

  /// MediaStack API 호출
  static Future<List<News>> _fetchFromMediaStack(String keyword, {int limit = 10}) async {
    try {
      final uri = Uri.parse(
        'http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4&keywords=$keyword&languages=en&countries=us&limit=$limit',
      );
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['data'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News(
          title: item['title']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
          link: item['url']?.toString() ?? '',
          publishedAt: item['published_at']?.toString() ?? '',
          source: item['source']?.toString() ?? 'MediaStack',
        )).toList();
      }
    } catch (e) {
      // MediaStack 오류
    }
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
}
