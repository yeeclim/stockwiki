import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'services/fmp_service.dart';
import 'services/krx_loader.dart';
import 'package:http/http.dart' as http;

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
  List<String> _results = []; // 미국 주식용
  List<MapEntry<String, dynamic>> _krEntries = []; // 국내 주식용
  bool _isLoading = false;
  String _marketType = 'us';

  String? _validateKeyword(String keyword) {
    final trimmed = keyword.trim();
    final isKorean = RegExp(r'^[가-힣]{2,}$').hasMatch(trimmed);
    final isNumber = RegExp(r'^\d{3,}$').hasMatch(trimmed);
    
    if (_marketType == 'kr') {
      if (!isKorean && !isNumber) {
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
      _krEntries.clear();
    });

    try {
      if (_marketType == 'us') {
        final stocks = await FMPService.fetchStocks(keyword);
        final result = stocks.map((s) => '${s.name} (${s.symbol}) - \$${s.price}').toList();
        setState(() {
          _results = result;
        });
      } else {
        final stock = await KrxLoader.searchStock(keyword);
        setState(() {
          _krEntries = stock.entries.toList();
        });
      }
    } catch (e) {
      setState(() {
        _results = ['오류 발생: $e'];
        _krEntries = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getValue(String key) {
    final match = _krEntries.firstWhere(
      (e) => e.key == key,
      orElse: () => const MapEntry('', 'N/A'),
    );
    return '${match.value}';
  }

  String _formatWon(String raw) {
    if (raw == 'N/A' || raw.isEmpty) return 'N/A';
    final num = int.tryParse(raw);
    if (num == null) return 'N/A';
    return '₩${num.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }

  String _getCodeFromPdno(String raw) {
    return raw.length >= 6 ? raw.substring(raw.length - 6) : raw;
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
              child: Text(
                'StockWiki',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
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
                  onChanged: (value) {
                    setState(() {
                      _marketType = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search keyword',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _searchStocks(),
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
                    : _krEntries.isEmpty
                        ? const Text('검색 결과 없음')
                        : ListView(
                            children: [
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _infoRow('종목명', _getValue('한글 종목명')),
                                      _infoRow('종목코드', _getCodeFromPdno(_getValue('단축코드'))),
                                      _infoRow('현재가', _formatWon(_getValue('open_price'))),
                                      _infoRow('전일가', _formatWon(_getValue('close_price'))),
                                      _infoRow('시가총액', _formatWon(_getValue('volume'))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
