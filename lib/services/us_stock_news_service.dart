import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news.dart';

class UsStockNewsService {
  /// 주식 관련 뉴스 조회 (서버사이드 news-search API 사용, API 키 불필요)
  static Future<List<News>> fetchStockNews(String symbol,
      {String? stockName, int limit = 10}) async {
    final keyword = stockName ?? symbol;
    return await searchNewsByKeyword(keyword, limit: limit);
  }

  // fetchMultipleStockNews / fetchMarketNews 가 여기 있었다. 둘 다 FMP
  // /stock_news 전용인데 FMP v3 가 2025-08-31 자로 폐기돼 항상 빈 목록을
  // 반환했고, 호출하는 화면도 없었다.

  /// 키워드 기반 뉴스 검색 (백엔드 프록시 사용)
  static Future<List<News>> searchNewsByKeyword(String keyword,
      {int limit = 20}) async {
    try {
      final baseUrl = Uri.base.origin;
      final encoded = Uri.encodeQueryComponent(keyword.trim());
      final uri = Uri.parse(
          '$baseUrl/api/news-search?keyword=$encoded&lang=en&limit=$limit');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        if (jsonData['success'] == true) {
          final results = jsonData['results'] as List<dynamic>? ?? [];
          return results
              .map<News>((item) {
                final title = item['title']?.toString() ?? '';
                final description = item['description']?.toString() ?? '';
                return News(
                  title: title,
                  description: description,
                  link: item['link']?.toString() ?? '',
                  publishedAt: item['publishedAt']?.toString() ?? '',
                  source: item['source']?.toString() ?? 'News',
                  // 상세 화면과 AI 위원회 화면이 news.sentiment 로 긍정/부정 뱃지를
                  // 그린다. FMP 경로에서만 감정 분석을 돌리고 있었던 탓에, FMP 가
                  // 폐기된 뒤로는 모든 뉴스가 'Neutral' 로 떨어져 뱃지가 사라졌다.
                  sentiment: _analyzeSentiment('$title $description'),
                );
              })
              .take(limit)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// 텍스트 감정 분석 (키워드 기반)
  static String _analyzeSentiment(String text) {
    if (text.isEmpty) return 'Neutral';
    final lowerText = text.toLowerCase();

    // 긍정 키워드
    final positiveKeywords = [
      'surge',
      'jump',
      'rise',
      'gain',
      'climb',
      'soar',
      'profit',
      'beat',
      'buy',
      'upgrade',
      'growth',
      'record',
      'bull',
      'positive',
      'high',
      'strong',
      'success',
      'deal',
      'agreement',
      'launch',
      'win',
      'rally'
    ];

    // 부정 키워드
    final negativeKeywords = [
      'plunge',
      'drop',
      'fall',
      'decline',
      'tumble',
      'loss',
      'miss',
      'sell',
      'downgrade',
      'crisis',
      'warn',
      'bear',
      'negative',
      'crash',
      'fail',
      'risk',
      'problem',
      'concern',
      'weak',
      'low',
      'down'
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
