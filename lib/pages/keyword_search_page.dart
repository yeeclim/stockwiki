import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import '../services/krx_loader.dart';
import '../widgets/stock_card.dart';

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
  bool _isKoreaSearch = true; // 기본값을 한국 주식으로 설정

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      List<Stock> results = [];
      
      if (_isKoreaSearch) {
        // 한국 주식 검색 (실시간 데이터 포함)
        final krxResults = await KrxLoader.searchStocks(keyword);
        results = krxResults.map((data) => Stock.fromKrxData(data)).toList();
      } else {
        // 미국 주식 검색
        results = await FMPService.fetchStocks(keyword);
      }
      
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
        title: Text(_isKoreaSearch ? 'StockWiki – 한국 주식 검색' : 'StockWiki – 미국 주식 검색'),
        actions: [
          IconButton(
            icon: Icon(_isKoreaSearch ? Icons.flag : Icons.flag_outlined),
            onPressed: () {
              setState(() {
                _isKoreaSearch = !_isKoreaSearch;
                _results.clear();
                _error = '';
              });
            },
            tooltip: _isKoreaSearch ? '미국 주식으로 전환' : '한국 주식으로 전환',
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
                      hintText: _isKoreaSearch ? '종목명 검색 (예: 삼성전자)' : 'Search keyword',
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
                if (_isKoreaSearch)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      KrxLoader.clearCache();
                      _search();
                    },
                    tooltip: '실시간 데이터 새로고침',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red))
            else if (_results.isEmpty)
              Text(
                _isKoreaSearch ? '한국 주식 검색 결과가 없습니다.' : '미국 주식 검색 결과가 없습니다.',
                style: const TextStyle(color: Colors.white)
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final stock = _results[index];
                    return StockCard(stock: stock);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
