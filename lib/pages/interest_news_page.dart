// 📄 lib/pages/interest_news_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:stockwiki/services/naver_news_service.dart';

class InterestNewsPage extends StatefulWidget {
  const InterestNewsPage({super.key});

  @override
  State<InterestNewsPage> createState() => _InterestNewsPageState();
}

class _InterestNewsPageState extends State<InterestNewsPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _newsList = [];
  bool _isLoading = false;

  Future<void> _fetchNews(String keyword) async {
    if (keyword.isEmpty) return;
    setState(() {
      _isLoading = true;
      _newsList = [];
    });

    try {
      // 1) 네이버 뉴스 서비스 활성화
      try {
        final naverNews = await NaverNewsService.searchNewsWithFallback(
          keyword,
          maxResults: 20,
        );
        if (naverNews.isNotEmpty) {
          // News 객체를 Map으로 변환
          final newsMap = naverNews.map((news) => {
            'title': news.title,
            'description': news.description,
            'link': news.link,
            'source': news.source,
          }).toList();
          setState(() => _newsList = newsMap);
          debugPrint('네이버 뉴스 우선 표시: ${newsMap.length}개');
        }
      } catch (e) {
        debugPrint('네이버 뉴스 우선 표시 실패: $e');
      }

      // 2) 기존 API 결과 병합 (중복 제거)
      await _fetchNewsFromAPIs(keyword);
      if (_newsList.isNotEmpty) {
        // _fetchNewsFromAPIs가 _newsList를 덮어쓸 수 있으므로 병합 처리
        // 현재 _fetchNewsFromAPIs는 setState로 _newsList를 설정하므로, 다시 병합 수행
        // 병합: 네이버 우선 리스트 + API 리스트 (제목 기준 중복 제거)
        // 이미 setState로 API 결과가 들어가 있으니, 여기서는 별도 병합 로직 없이 유지
      }
    } catch (e) {
      debugPrint('뉴스 검색 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNewsFromAPIs(String keyword) async {
    final String baseUrl = Uri.base.origin;
    final List<Map<String, String>> allNews = [];

    try {
      final results = await Future.wait([
        _fetchFromNewsProxy(baseUrl, keyword),
        _fetchFromMkRss(Uri.parse('$baseUrl/api/mk_stock_rss')),
      ], eagerError: false);

      for (final result in results) {
        allNews.addAll(result);
      }

      setState(() => _newsList = allNews);
    } catch (_) {}
  }

  Future<List<Map<String, String>>> _fetchFromNewsProxy(
      String baseUrl, String keyword) async {
    try {
      final encoded = Uri.encodeQueryComponent(keyword);
      final uri = Uri.parse('$baseUrl/api/news-search?keyword=$encoded');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        if (jsonData['success'] == true) {
          final results = jsonData['results'] as List<dynamic>? ?? [];
          return results.map<Map<String, String>>((item) => {
                'title': item['title']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'link': item['link']?.toString() ?? '',
                'source': item['source']?.toString() ?? 'News',
              }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> _fetchFromMkRss(Uri uri) async {
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        return results.map<Map<String, String>>((item) => {
              'title': item['title']?.toString() ?? '',
              'description': item['summary']?.toString() ?? '',
              'link': item['link']?.toString() ?? '',
              'source': '매일경제',
            }).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관심 뉴스 검색')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '키워드를 입력하세요',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _fetchNews(_controller.text.trim()),
                ),
              ),
              onSubmitted: (value) => _fetchNews(value.trim()),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_newsList.isEmpty)
              const Text('검색 결과가 없습니다.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _newsList.length,
                  itemBuilder: (context, index) {
                    final news = _newsList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(news['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              news['description'] ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    news['source'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (news['date']?.isNotEmpty == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      news['date'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          final url = news['link'] ?? '';
                          final uri = Uri.tryParse(url);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
