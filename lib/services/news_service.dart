// lib/services/news_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news.dart';
import 'naver_news_service.dart';

class NewsService {
  static const int _maxResults = 8; // 종목별 뉴스는 8개로 증가

  /// 종목명으로 관련 뉴스를 검색합니다 (네이버 뉴스 우선)
  static Future<List<News>> searchStockNews(String stockName) async {
    if (stockName.isEmpty) return [];

    try {
      final List<News> allNews = [];
      
      // 1. 네이버 뉴스 크롤링 우선 시도
      try {
        final naverNews = await NaverNewsService.searchNaverNews(stockName, maxResults: 5);
        if (naverNews.isNotEmpty) {
          allNews.addAll(naverNews);
          print('네이버 뉴스 크롤링 성공: ${naverNews.length}개');
        }
      } catch (e) {
        print('네이버 뉴스 크롤링 실패: $e');
      }

      // 2. 다음 뉴스 크롤링 시도
      try {
        final daumNews = await _fetchFromDaumNews(stockName);
        if (daumNews.isNotEmpty) {
          allNews.addAll(daumNews);
          print('다음 뉴스 크롤링 성공: ${daumNews.length}개');
        }
      } catch (e) {
        print('다음 뉴스 크롤링 실패: $e');
      }

      // 3. 구글 뉴스 검색 시도
      try {
        final googleNews = await _fetchFromGoogleNews(stockName);
        if (googleNews.isNotEmpty) {
          allNews.addAll(googleNews);
          print('구글 뉴스 검색 성공: ${googleNews.length}개');
        }
      } catch (e) {
        print('구글 뉴스 검색 실패: $e');
      }

      // 4. 뉴스가 부족하면 기존 API들로 보완
      if (allNews.length < _maxResults) {
        final String baseUrl = Uri.base.origin;
        
        // 기존 API들을 병렬로 호출
        final futures = [
          _fetchFromNewsData(stockName),
          _fetchFromGNews(stockName),
          _fetchFromMediaStack(stockName),
          _fetchFromMkRss(baseUrl, stockName),
        ];

        final results = await Future.wait(futures, eagerError: false);

        for (final result in results) {
          allNews.addAll(result);
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
      
      print('최종 뉴스 결과: ${finalNews.length}개 (네이버: ${allNews.where((n) => n.source == '네이버 뉴스').length}개)');
      
      return finalNews;
    } catch (e) {
      print('뉴스 검색 오류: $e');
      return [];
    }
  }

  static Future<List<News>> _fetchFromNewsData(String keyword) async {
    try {
      final uri = Uri.parse(
          'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$keyword&language=ko,en&country=kr');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        
        print('NewsData.io: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['link']?.toString() ?? '',
              'source': 'NewsData.io',
              'publishedAt': item['pubDate']?.toString(),
            })).toList();
      } else {
        print('NewsData.io HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('NewsData.io 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromGNews(String keyword) async {
    try {
      final uri = Uri.parse(
          'https://gnews.io/api/v4/search?token=6c6fdfc93ae9225b3bd4210978798fc1&q=$keyword&lang=ko,en&country=kr');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['articles'] as List<dynamic>? ?? [];
        
        print('GNews: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'GNews',
              'publishedAt': item['publishedAt']?.toString(),
            })).toList();
      } else {
        print('GNews HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('GNews 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromMediaStack(String keyword) async {
    try {
      final uri = Uri.parse(
          'http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4&keywords=$keyword&languages=ko,en&countries=kr');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['data'] as List<dynamic>? ?? [];
        
        print('MediaStack: ${results.length}개 결과');
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'MediaStack',
              'publishedAt': item['published_at']?.toString(),
            })).toList();
      } else {
        print('MediaStack HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('MediaStack 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromMkRss(String baseUrl, String keyword) async {
    try {
      final uri = Uri.parse('$baseUrl/api/mk_stock_rss');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        // 응답이 HTML인지 JSON인지 확인
        final responseText = utf8.decode(response.bodyBytes);
        if (responseText.trim().startsWith('<!DOCTYPE') || responseText.trim().startsWith('<html')) {
          print('MK Stock RSS: HTML 응답 받음, JSON이 아님');
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
      print('MK Stock RSS 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromDaumNews(String keyword) async {
    try {
      final String baseUrl = Uri.base.origin;
      final uri = Uri.parse('$baseUrl/api/daum_news');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'keyword': keyword,
          'max_results': 5,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        
        if (jsonData['success'] == true && jsonData['results'] != null) {
          final results = jsonData['results'] as List<dynamic>;
          
          return results.map<News>((item) => News.fromJson({
                'title': item['title']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'link': item['link']?.toString() ?? '',
                'source': '다음 뉴스',
                'publishedAt': item['published_at']?.toString(),
              })).toList();
        }
      }
      
      print('다음 뉴스 API 응답 오류: ${response.statusCode}');
      return [];
    } catch (e) {
      print('다음 뉴스 API 오류: $e');
      return [];
    }
  }

  static Future<List<News>> _fetchFromGoogleNews(String keyword) async {
    try {
      final String baseUrl = Uri.base.origin;
      final uri = Uri.parse('$baseUrl/api/google_news');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'keyword': keyword,
          'max_results': 5,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        
        if (jsonData['success'] == true && jsonData['results'] != null) {
          final results = jsonData['results'] as List<dynamic>;
          
          return results.map<News>((item) => News.fromJson({
                'title': item['title']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'link': item['link']?.toString() ?? '',
                'source': '구글 뉴스',
                'publishedAt': item['published_at']?.toString(),
              })).toList();
        }
      }
      
      print('구글 뉴스 API 응답 오류: ${response.statusCode}');
      return [];
    } catch (e) {
      print('구글 뉴스 API 오류: $e');
      return [];
    }
  }

}
