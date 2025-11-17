// lib/pages/test_news_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/news_service.dart';
import '../models/news.dart';

class TestNewsPage extends StatefulWidget {
  const TestNewsPage({super.key});

  @override
  State<TestNewsPage> createState() => _TestNewsPageState();
}

class _TestNewsPageState extends State<TestNewsPage> {
  final TextEditingController _controller = TextEditingController();
  List<News> _newsList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = '대창솔루션'; // 기본값 설정
  }

  Future<void> _searchNews() async {
    if (_controller.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _newsList = [];
    });

    try {
      final news = await NewsService.searchStockNews(_controller.text);
      setState(() {
        _newsList = news;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('뉴스 검색 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('뉴스 테스트'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '종목명을 입력하세요',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchNews,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('검색'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Text(
                  '뉴스를 불러오는 중...',
                  style: TextStyle(color: Colors.white60),
                ),
              )
            else if (_newsList.isEmpty && _controller.text.isNotEmpty)
              const Center(
                child: Text(
                  '뉴스를 찾을 수 없습니다',
                  style: TextStyle(color: Colors.white60),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _newsList.length,
                  itemBuilder: (context, index) {
                    final news = _newsList[index];
                    return Card(
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          news.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (news.description.isNotEmpty)
                              Text(
                                news.description,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  news.source,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                if (news.publishedAt != null)
                                  Text(
                                    _formatTime(news.publishedAt!),
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          // 링크 열기 로직 추가 가능
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

  String _formatTime(String publishedAt) {
    try {
      final dateTime = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else {
        return '${dateTime.month}/${dateTime.day}';
      }
    } catch (e) {
      return '알 수 없음';
    }
  }
}
