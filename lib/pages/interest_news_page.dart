// 📄 lib/pages/interest_news_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

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
    setState(() => _isLoading = true);

    final lowerKeyword = keyword.toLowerCase();
    final String baseUrl = kReleaseMode
        ? 'https://stockwiki.vercel.app'
        : 'http://localhost:3000';
    final mkStockRssUri = Uri.parse('$baseUrl/api/mk_stock_rss');

    final newsdataUri = Uri.parse(
        'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=');
    final gnewsUri = Uri.parse(
        'https://gnews.io/api/v4/top-headlines?token=6c6fdfc93ae9225b3bd4210978798fc1');
    final mediastackUri = Uri.parse(
        'http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4');

    List<Map<String, String>> allNews = [];

    try {
      final responses = await Future.wait([
        http.get(newsdataUri),
        http.get(gnewsUri),
        http.get(mediastackUri),
        http.get(mkStockRssUri),
      ]);

      // NewsData.io
      if (responses[0].statusCode == 200) {
        final jsonData = json.decode(utf8.decode(responses[0].bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        allNews.addAll(results.map((item) => {
              'title': item['title'] ?? '',
              'description': item['description'] ?? '',
              'link': item['link'] ?? '',
            }));
      }

      // GNews
      if (responses[1].statusCode == 200) {
        final jsonData = json.decode(utf8.decode(responses[1].bodyBytes));
        final results = jsonData['articles'] as List<dynamic>? ?? [];
        allNews.addAll(results.map((item) => {
              'title': item['title'] ?? '',
              'description': item['description'] ?? '',
              'link': item['url'] ?? '',
            }));
      }

      // MediaStack
      if (responses[2].statusCode == 200) {
        final jsonData = json.decode(utf8.decode(responses[2].bodyBytes));
        final results = jsonData['data'] as List<dynamic>? ?? [];
        allNews.addAll(results.map((item) => {
              'title': item['title'] ?? '',
              'description': item['description'] ?? '',
              'link': item['url'] ?? '',
            }));
      }

      // MK RSS
      if (responses[3].statusCode == 200) {
        final jsonData = json.decode(utf8.decode(responses[3].bodyBytes));
        final results = jsonData['results'] as List<dynamic>? ?? [];
        allNews.addAll(results.map((item) => {
              'title': item['title'] ?? '',
              'description': item['summary'] ?? '',
              'link': item['link'] ?? '',
            }));
      }

      // 최종 필터링: keyword 포함 여부 확인
      final filteredNews = allNews.where((news) {
        final combined = '${news['title'] ?? ''} ${news['description'] ?? ''}'.toLowerCase();
        return combined.contains(lowerKeyword);
      }).toList();

      setState(() => _newsList = filteredNews);
    } catch (e) {
      debugPrint('예외 발생: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
                        subtitle: Text(
                          news['description'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
