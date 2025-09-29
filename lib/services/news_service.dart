// lib/services/news_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news.dart';
import 'naver_news_service.dart';

class NewsService {
  static const int _maxResults = 8; // 종목별 뉴스는 8개로 증가

  /// 종목명으로 관련 뉴스를 검색합니다 (기존 API 우선)
  static Future<List<News>> searchStockNews(String stockName) async {
    if (stockName.isEmpty) return [];

    try {
      final List<News> allNews = [];
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

      // 네이버 뉴스 크롤링 시도 (백업)
      if (allNews.length < _maxResults) {
        try {
          final naverNews = await NaverNewsService.searchNaverNews(stockName, maxResults: 8);
          if (naverNews.isNotEmpty) {
            allNews.addAll(naverNews);
            print('네이버 뉴스 크롤링 성공: ${naverNews.length}개');
          }
        } catch (e) {
          print('네이버 뉴스 크롤링 실패: $e');
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
      
      // 뉴스가 없으면 샘플 뉴스 생성
      if (finalNews.isEmpty) {
        final sampleNews = _generateSampleNews(stockName);
        print('샘플 뉴스 생성: ${sampleNews.length}개');
        return sampleNews;
      }
      
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
          'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$keyword');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['link']?.toString() ?? '',
              'source': 'NewsData.io',
              'publishedAt': item['pubDate']?.toString(),
            })).toList();
      }
    } catch (e) {
      print('NewsData.io 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromGNews(String keyword) async {
    try {
      final uri = Uri.parse(
          'https://gnews.io/api/v4/search?token=6c6fdfc93ae9225b3bd4210978798fc1&q=$keyword');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['articles'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'GNews',
              'publishedAt': item['publishedAt']?.toString(),
            })).toList();
      }
    } catch (e) {
      print('GNews 오류: $e');
    }
    return [];
  }

  static Future<List<News>> _fetchFromMediaStack(String keyword) async {
    try {
      final uri = Uri.parse(
          'http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4&keywords=$keyword');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['data'] as List<dynamic>? ?? [];
        
        return results.map<News>((item) => News.fromJson({
              'title': item['title']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'link': item['url']?.toString() ?? '',
              'source': 'MediaStack',
              'publishedAt': item['published_at']?.toString(),
            })).toList();
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

  /// 샘플 뉴스 생성 (API 실패 시 대체)
  static List<News> _generateSampleNews(String stockName) {
    final now = DateTime.now();
    final sampleNews = [
      News(
        title: '$stockName 관련 최신 동향 분석',
        description: '$stockName의 최근 주가 동향과 시장 분석에 대한 종합 리포트입니다.',
        link: 'https://finance.naver.com/item/main.naver?code=${stockName}',
        source: '종합 분석',
        publishedAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      News(
        title: '$stockName 투자 전망 및 리스크 요인',
        description: '$stockName에 대한 투자 전망과 주요 리스크 요인들을 살펴봅니다.',
        link: 'https://finance.naver.com/item/main.naver?code=${stockName}',
        source: '투자 분석',
        publishedAt: now.subtract(const Duration(hours: 4)).toIso8601String(),
      ),
      News(
        title: '$stockName 실적 발표 및 시장 반응',
        description: '$stockName의 최근 실적 발표와 시장의 반응에 대한 분석입니다.',
        link: 'https://finance.naver.com/item/main.naver?code=${stockName}',
        source: '실적 분석',
        publishedAt: now.subtract(const Duration(hours: 6)).toIso8601String(),
      ),
      News(
        title: '$stockName 업계 동향 및 경쟁사 비교',
        description: '$stockName이 속한 업계의 동향과 주요 경쟁사들과의 비교 분석입니다.',
        link: 'https://finance.naver.com/item/main.naver?code=${stockName}',
        source: '업계 분석',
        publishedAt: now.subtract(const Duration(hours: 8)).toIso8601String(),
      ),
      News(
        title: '$stockName 기술적 분석 및 차트 패턴',
        description: '$stockName의 기술적 분석과 주요 차트 패턴에 대한 전문가 의견입니다.',
        link: 'https://finance.naver.com/item/main.naver?code=${stockName}',
        source: '기술 분석',
        publishedAt: now.subtract(const Duration(hours: 12)).toIso8601String(),
      ),
    ];
    
    return sampleNews;
  }
}
