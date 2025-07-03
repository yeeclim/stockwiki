// 📄 lib/main.dart
import 'package:flutter/material.dart';
import 'package:stockwiki/services/fmp_service.dart';
import 'package:stockwiki/services/krx_loader.dart';
import 'package:stockwiki/widgets/fed_watch_widget.dart';
import 'package:stockwiki/widgets/fear_greed_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockWiki',
      theme: ThemeData.dark(),
      home: const StockSearchPage(),
    );
  }
}

class StockSearchPage extends StatefulWidget {
  const StockSearchPage({super.key});

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends State<StockSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];
  List<Map<String, dynamic>> _krResults = [];
  bool _isLoading = false;
  String _marketType = 'us';

  String? _validateKeyword(String keyword) {
    final trimmed = keyword.trim();
    final containsKorean = RegExp(r'[\uac00-\ud7a3]').hasMatch(trimmed);
    final containsNumber = RegExp(r'\d').hasMatch(trimmed);
    if (trimmed.length < 2) {
      return '한글 2자 이상 또는 숫자 3자 이상 입력해주세요';
    }
    if (_marketType == 'kr') {
      if (!containsKorean && !containsNumber) {
        return '한글 2자 이상 또는 숫자 3자 이상 입력해주세요';
      }
    }
    return null;
  }

  void _searchStocks() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    final validationMessage = _validateKeyword(keyword);
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationMessage)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _results.clear();
      _krResults.clear();
    });

    try {
      if (_marketType == 'us') {
        final stocks = await FMPService.fetchStocks(keyword);
        final result = stocks.map((s) => '${s.name} (${s.symbol}) - \$${s.price}').toList();
        setState(() {
          _results = result;
        });
      } else {
        final list = await KrxLoader.searchStocks(keyword);
        setState(() {
          _krResults = list;
        });
      }
    } catch (e) {
      setState(() {
        _results = ['오류 발생: $e'];
        _krResults = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$title:', style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatWon(dynamic raw) {
    final str = raw.toString();
    if (str.isEmpty || str == 'null') return 'N/A';
    final num = int.tryParse(str);
    if (num == null) return 'N/A';
    return '₩${num.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            const Center(
              child: Text('StockWiki', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("종류: ", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _marketType,
                  items: const [
                    DropdownMenuItem(value: 'us', child: Text('미국주식')),
                    DropdownMenuItem(value: 'kr', child: Text('국내주식')),
                  ],
                  onChanged: (value) => setState(() => _marketType = value!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search keyword',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (_) => _searchStocks(),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: FedWatchWidget()),
                SizedBox(width: 12),
                Expanded(child: FearGreedWidget()),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: _marketType == 'us'
                    ? ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(_results[index]),
                        ),
                      )
                    : _krResults.isEmpty
                        ? const Text('검색 결과 없음')
                        : ListView.builder(
                            itemCount: _krResults.length,
                            itemBuilder: (context, index) {
                              final stock = _krResults[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _infoRow('종목명', stock['한글 종목명'].toString()),
                                      _infoRow('종목코드', stock['단축코드'].toString()),
                                      _infoRow('현재가', _formatWon(stock['open_price'])),
                                      _infoRow('전일가', _formatWon(stock['close_price'])),
                                      _infoRow('시가총액', _formatWon(stock['market_cap'])),
                                    ],
                                  ),
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
