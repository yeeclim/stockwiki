import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import '../widgets/stock_card.dart';
import 'us_stock_detail_page.dart';

class UsStockSearchPage extends StatefulWidget {
  const UsStockSearchPage({super.key});

  @override
  State<UsStockSearchPage> createState() => _UsStockSearchPageState();
}

class _UsStockSearchPageState extends State<UsStockSearchPage> {
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
      // 미국 주식 검색
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
      appBar: AppBar(
        title: const Text('StockWiki – 미국 주식 검색'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _controller.clear();
              setState(() {
                _results.clear();
                _error = '';
              });
            },
            tooltip: '검색 초기화',
          ),
        ],
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
                    onSubmitted: (_) => _search(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search keyword (예: Apple, AAPL)',
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _search,
                  tooltip: '검색 새로고침',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
            else if (_results.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: const Text(
                  '미국 주식 검색 결과가 없습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final stock = _results[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            stock.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${stock.symbol} - \$${stock.price?.toStringAsFixed(2) ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                          trailing: stock.changePercent != null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: stock.changePercent! >= 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      stock.changePercent! >= 0 ? Icons.trending_up : Icons.trending_down,
                                      color: stock.changePercent! >= 0 ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UsStockDetailPage(stock: stock),
                              ),
                            );
                          },
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
