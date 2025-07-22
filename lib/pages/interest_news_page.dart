// 📄 lib/pages/interest_news_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

    final uri = Uri.parse(
      'https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$keyword&country=kr&language=ko',
    );

    try {
      final response = await http.get(uri, headers: {
        "Accept-Charset": "utf-8",
      });
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(decoded);
        final List<dynamic>? results = jsonData['results'];

        if (results != null) {
          final cleaned = results.map((item) => {
            'title': item['title']?.toString().trim() ?? '',
            'description': item['description']?.toString().trim() ?? '',
            'link': item['link']?.toString().trim() ?? '',
          }).toList();

          setState(() => _newsList = cleaned);
        }
      } else {
        debugPrint('뉴스 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('예외 발생: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 관심 뉴스 검색')),
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
