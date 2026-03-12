// lib/services/news_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/news.dart';
import 'naver_news_service.dart';

class NewsService {
  static const int _maxResults = 8; // 종목별 뉴스는 8개로 증가
  
  // 뉴스 캐시 (5분간 유효)
  static final Map<String, List<News>> _newsCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// 종목명으로 관련 뉴스를 검색합니다 (국내/해외 구분)
  static Future<List<News>> searchStockNews(String stockName, {bool isKoreanStock = true}) async {
    if (stockName.isEmpty) return [];

    // 캐시 확인
    final cacheKey = '${stockName}_${isKoreanStock ? 'kr' : 'us'}';
    final now = DateTime.now();
    
    if (_newsCache.containsKey(cacheKey) && 
        _cacheTime.containsKey(cacheKey) &&
        now.difference(_cacheTime[cacheKey]!) < _cacheExpiry) {
      debugPrint('뉴스 캐시 사용: $stockName');
      return _newsCache[cacheKey]!;
    }

    try {
      final List<News> allNews = [];
      

      // 1. 주요 뉴스 소스들을 병렬로 처리
      final futures = <Future<List<News>>>[];
      
      // 네이버 뉴스 (국내주식만)
      if (isKoreanStock) {
        futures.add(NaverNewsService.searchNaverNews(stockName, maxResults: 3).catchError((e) {
          debugPrint('네이버 뉴스 크롤링 실패: $e');
          return <News>[];
        }));
      }
      
      // 다음 뉴스 (항상 시도)
      futures.add(_fetchFromDaumNews(stockName).catchError((e) {
        debugPrint('다음 뉴스 크롤링 실패: $e');
        return <News>[];
      }));
      
      // 병렬로 실행 (타임아웃 5초로 단축)
      final results = await Future.wait(futures, eagerError: false)
          .timeout(Duration(seconds: 5), onTimeout: () {
        debugPrint('뉴스 로딩 타임아웃 (5초)');
        return <List<News>>[];
      });
      
      // 결과 합치기
      for (final result in results) {
        allNews.addAll(result);
      }

      // 2. 뉴스가 부족하면 추가 뉴스 소스로 보완
      if (allNews.length < _maxResults) {
        final String baseUrl = Uri.base.origin;
        
        if (isKoreanStock) {
          // 국내주식: 국내 뉴스 API만 사용
          try {
            final mkRssNews = await _fetchFromMkRss(baseUrl, stockName);
            if (mkRssNews.isNotEmpty) {
              allNews.addAll(mkRssNews);
              debugPrint('MK Stock RSS 성공: ${mkRssNews.length}개');
            }
          } catch (e) {
            debugPrint('MK Stock RSS 실패: $e');
          }
        } else {
          // 미국주식: 해외 뉴스 API들을 병렬로 호출 (3초 타임아웃)
          try {
            final results = await Future.wait([
              _fetchFromNewsData(stockName),
              _fetchFromGNews(stockName),
              _fetchFromMediaStack(stockName),
            ], eagerError: false).timeout(const Duration(seconds: 3));

            for (final result in results) {
              allNews.addAll(result);
            }
          } catch (e) {
            debugPrint('미국 뉴스 API 타임아웃: $e');
          }
        }
      }

      // 중복 제거 (제목 기준)
      final uniqueNews = <String, News>{};
      for (final news in allNews) {
        if (news.title.isNotEmpty && !uniqueNews.containsKey(news.title)) {
          uniqueNews[news.title] = news;
        }
      }

      // 최대 결과 수로 제한
      final finalNews = uniqueNews.values.take(_maxResults).toList();
      
      debugPrint('최종 뉴스 결과: ${finalNews.length}개 (StockWiki: ${allNews.where((n) => n.source == 'StockWiki News').length}개)');
      
      // 캐시에 저장
      _newsCache[cacheKey] = finalNews;
      _cacheTime[cacheKey] = now;
      
      return finalNews;
    } catch (e) {
      debugPrint('뉴스 검색 오류: $e');
      return [];
    }
  }

  static Future<List<News>> _fetchFromNewsData(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(
          'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$keyword&language=ko,en&country=kr&t=$timestamp');
      final response = await http.get(uri, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        
        debugPrint('NewsData.io: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['link']?.toString() ?? '',
              'source': 'NewsData.io',
              'publishedAt': item['pubDate']?.toString(),
            })).toList();
      } else {
        debugPrint('NewsData.io HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('NewsData.io 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromGNews(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(
          'https://gnews.io/api/v4/search?token=6c6fdfc93ae9225b3bd4210978798fc1&q=$keyword&lang=ko,en&country=kr&t=$timestamp');
      final response = await http.get(uri, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['articles'] as List<dynamic>? ?? [];
        
        debugPrint('GNews: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'GNews',
              'publishedAt': item['publishedAt']?.toString(),
            })).toList();
      } else {
        debugPrint('GNews HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('GNews 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromMediaStack(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(
          'http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4&keywords=$keyword&languages=ko,en&countries=kr&timestamp=$timestamp');
      final response = await http.get(uri, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['data'] as List<dynamic>? ?? [];
        
        debugPrint('MediaStack: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'MediaStack',
              'publishedAt': item['published_at']?.toString(),
            })).toList();
      } else {
        debugPrint('MediaStack HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MediaStack 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromMkRss(String baseUrl, String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$baseUrl/api/news?source=mk_rss&t=$timestamp');
      final response = await http.get(uri, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        // 응답이 HTML인지 JSON인지 확인
        final responseText = utf8.decode(response.bodyBytes);
        if (responseText.trim().startsWith('<!DOCTYPE') || responseText.trim().startsWith('<html')) {
          debugPrint('MK Stock RSS: HTML 응답 받음, JSON이 아님');
          return [];
        }
        
        final jsonData = json.decode(responseText);
        final results = jsonData['results'] as List<dynamic>? ?? [];
        
        // 키워드가 포함된 뉴스만 필터링
        final filteredResults = results.where((item) {
          final title = item['title']?.toString().toLowerCase() ?? '';
          final description = item['description']?.toString().toLowerCase() ?? '';
          final lowerKeyword = keyword.toLowerCase();
          return title.contains(lowerKeyword) || description.contains(lowerKeyword);
        }).toList();
        
        return filteredResults.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['link']?.toString() ?? '',
              'source': 'MK Stock RSS',
              'publishedAt': item['publishedAt']?.toString(),
            })).toList();
      }
    } catch (e) {
      debugPrint('MK Stock RSS 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromDaumNews(String keyword) async {
    try {
      final String baseUrl = Uri.base.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$baseUrl/api/news?source=daum&t=$timestamp');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
        body: json.encode({
          'keyword': keyword,
          'max_results': 5,
          'timestamp': timestamp,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        
        if (jsonData['success'] == true && jsonData['results'] != null) {
          final results = jsonData['results'] as List<dynamic>;
          
          return results.map<News>((item) => News.fromJson({
                'title': item['title']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'link': item['link']?.toString() ?? '',
                'source': item['source']?.toString() ?? '다음뉴스',
                'publishedAt': item['published_at']?.toString(),
              })).toList();
        }
      }
      
      debugPrint('다음 뉴스 API 응답 오류: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('다음 뉴스 API 오류: $e');
      return [];
    }
  }

}
