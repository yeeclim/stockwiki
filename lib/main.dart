import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/fmp_service.dart';
import 'services/kis_service.dart';

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

  final KisService _kisService = KisService();

  void _searchStocks() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

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
        final stockInfoMap = await _kisService.fetchStockInfo(keyword);
        setState(() {
          _krEntries = stockInfoMap.entries.toList();
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

  String _formatDate(String raw) {
    if (raw.length != 8) return raw;
    return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6)}';
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
                                      _infoRow('종목명', _getValue('prdt_name')),
                                      _infoRow('종목코드', _getCodeFromPdno(_getValue('pdno'))),
                                      _infoRow('현재가', _formatWon(_getValue('thdt_clpr'))),
                                      _infoRow('전일가', _formatWon(_getValue('bfdy_clpr'))),
                                      _infoRow('시가총액', _formatWon(_getValue('cpta'))),
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
