// lib/services/naver_news_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news.dart';

class NaverNewsService {
  /// 네이버 뉴스 크롤링을 통해 뉴스를 검색합니다
  static Future<List<News>> searchNaverNews(String keyword, {int maxResults = 10}) async {
    if (keyword.isEmpty) return [];

    try {
      final String baseUrl = Uri.base.origin;
      final uri = Uri.parse('$baseUrl/api/naver_news_python');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'keyword': keyword,
          'max_results': maxResults,
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
                'source': '네이버 뉴스',
                'publishedAt': item['published_at']?.toString(),
              })).toList();
        }
      }
      
      print('네이버 뉴스 API 응답 오류: ${response.statusCode}');
      return [];
    } catch (e) {
      print('네이버 뉴스 크롤링 오류: $e');
      return [];
    }
  }

  /// 네이버 뉴스 크롤링과 기존 API를 함께 사용하여 뉴스를 검색합니다
  static Future<List<News>> searchNewsWithFallback(String keyword, {int maxResults = 10}) async {
    if (keyword.isEmpty) return [];

    try {
      // 1. 네이버 뉴스 크롤링 시도
      final naverNews = await searchNaverNews(keyword, maxResults: maxResults);
      
      if (naverNews.isNotEmpty) {
        print('네이버 뉴스 크롤링 성공: ${naverNews.length}개');
        return naverNews;
      }
      
      print('네이버 뉴스 크롤링 실패, 빈 결과 반환');
      return [];
    } catch (e) {
      print('네이버 뉴스 크롤링 전체 실패: $e');
      return [];
    }
  }
}
