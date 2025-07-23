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

  final List<String> _filterKeywords = [
    '경제', '주가', '금리', '증시', '투자', '인플레이션', '환율',
    '무역', '산업', '기업', '코스피', '나스닥', 'IT',
    'economy', 'stock', 'market', 'investment', 'inflation', 'exchange rate',
    'CPI', 'PPI', 'FOMC', 'Fed', 'Goldman Sachs', 'Morgan Stanley', 'JP Morgan',

    '거버넌스', '지배구조', '지속가능성', 'IR', 'ESG', '지주사',
    '실적', '이익', '순이익', '매출', '수익', '자본', '재무제표',
    '자사주매입', '소각', '배당', '유상증자', '무상증자', '상장', 'IPO',
    '해외법인', '신사업', '인수합병', 'M&A', '합작회사', '계열사',
    '주주총회', '이사회', '리스크', '불확실성', '금','은','유가',
    'S&P500', '나스닥100', 'KOSPI200', 'DOW', 'NASDAQ', 'NYSE',
    'KODEX', 'TIGER', 'HANARO', 'KBSTAR',
    '삼성전자', 'SK하이닉스', 'LG에너지솔루션', 'POSCO', '현대차', '기아', '네이버', '카카오',
    '금리인상', '금리동결', '양적완화', '긴축', '디플레이션', '스태그플레이션', '위기', '리세션', 'recession', 'stagflation', 'deflation',
    'China risk', '우크라이나', '지정학', '전쟁', '중동', '이스라엘', '팔레스타인',
    'bitcoin', 'btc', 'ethereum', 'eth', 'crypto', 'binance', '코인', '가상화폐',

    'governance', 'subsidiary', 'earnings', 'profit', 'revenue', 'sales', 'margin', 'gold', 'silver', 'WTI',
    'dividend', 'buyback', 'repurchase', 'merger', 'acquisition',
    'joint venture', 'subsidiary', 'board of directors', 'shareholder meeting',
    'capital', 'balance sheet', 'sustainability', 'IPO', 'listing', 'IR',
    'SPY', 'QQQ', 'DIA', 'IVV', 'VOO', 'VTI', 'VT',
    'TQQQ', 'SQQQ', 'SOXL', 'SOXS', 'LABU', 'LABD',
    'ARKK', 'XLF', 'XLE', 'XLK', 'XLV', 'XLY', 'XLC',
    'AAPL', 'GOOGL', 'MSFT', 'AMZN', 'TSLA', 'META', 'NVDA',
  ];

  bool _isAllowed(Map<String, String> news) {
    final content = '${news['title'] ?? ''}'.toLowerCase();
    return _filterKeywords.any((keyword) => content.contains(keyword.toLowerCase()));
  }

  Future<void> _fetchNews(String keyword) async {
    if (keyword.isEmpty) return;
    setState(() => _isLoading = true);

    final encodedKeyword = Uri.encodeComponent(keyword);

    final newsdataUri = Uri.parse('https://newsdata.io/api/1/news?apikey=pub_482bf5f3aa4249f7850c5818558ed551&q=$encodedKeyword',);
    final gnewsUri = Uri.parse('https://gnews.io/api/v4/search?q=$encodedKeyword&token=6c6fdfc93ae9225b3bd4210978798fc1',);
    final mediastackUri = Uri.parse('http://api.mediastack.com/v1/news?access_key=fe222fa0883ffaceee36f639a9cd82b4&keywords=$encodedKeyword',);

    List<Map<String, String>> allNews = [];

    try {
      final responses = await Future.wait([
        http.get(newsdataUri),
        http.get(gnewsUri),
        http.get(mediastackUri),
      ]);

      // NewsData.io
      if (responses[0].statusCode == 200) {
        final decoded = utf8.decode(responses[0].bodyBytes);
        final jsonData = json.decode(decoded);
        final results = jsonData['results'] ?? [];
        allNews.addAll(
          results
              .map((item) => Map<String, String>.from({
                    'title': item['title'] ?? '',
                    //'description': item['description'] ?? '',
                    'link': item['link'] ?? '',
                  }))
              .cast<Map<String, String>>()
              .where((news) => _isAllowed(news))
              .toList(),
        );
      }

      // GNews
      if (responses[1].statusCode == 200) {
        final decoded = utf8.decode(responses[1].bodyBytes);
        final jsonData = json.decode(decoded);
        final results = jsonData['articles'] ?? [];
        allNews.addAll(
          results
              .map((item) => Map<String, String>.from({
                    'title': item['title'] ?? '',
                    //'description': item['description'] ?? '',
                    'link': item['url'] ?? '',
                  }))
              .cast<Map<String, String>>()
              .where((news) => _isAllowed(news))
              .toList(),
        );
      }

      // MediaStack
      if (responses[2].statusCode == 200) {
        final decoded = utf8.decode(responses[2].bodyBytes);
        final jsonData = json.decode(decoded);
        final results = jsonData['data'] ?? [];
        allNews.addAll(
          results
              .map((item) => Map<String, String>.from({
                    'title': item['title'] ?? '',
                    //'description': item['description'] ?? '',
                    'link': item['url'] ?? '',
                  }))
              .cast<Map<String, String>>()
              .where((news) => _isAllowed(news))
              .toList(),
        );
      }

      setState(() => _newsList = allNews);
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
