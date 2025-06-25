import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';

class KeywordSearchPage extends StatefulWidget {
  const KeywordSearchPage({super.key});

  @override
  State<KeywordSearchPage> createState() => _KeywordSearchPageState();
}

class _KeywordSearchPageState extends State<KeywordSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Stock> _results = [];
  bool _isLoading = false;
  String _error = '';

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final results = await FMPService.fetchStocks(keyword);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = '검색 중 오류 발생: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('StockWiki – 미국 주식 검색')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search keyword',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red))
            else if (_results.isEmpty)
              const Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.white))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final stock = _results[index];
                    return ListTile(
                      title: Text('${stock.symbol} – ${stock.name}', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Price: \$${stock.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
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
