// 📄 lib/main.dart
import 'package:flutter/material.dart';
import 'package:stockwiki/services/fmp_service.dart';
import 'package:stockwiki/services/krx_loader.dart';
import 'package:stockwiki/widgets/fear_greed_widget.dart';
import 'package:stockwiki/widgets/usdkrw_widget.dart';
import 'package:stockwiki/widgets/gold_widget.dart';
import 'package:stockwiki/widgets/silver_widget.dart';
import 'package:stockwiki/widgets/wti_widget.dart';
import 'package:stockwiki/widgets/btc_widget.dart';
import 'package:stockwiki/pages/interest_news_page.dart';
import 'package:stockwiki/pages/us_stock_detail_page.dart';
import 'package:stockwiki/pages/us_stock_search_page.dart';
import 'package:stockwiki/pages/keyword_search_page.dart';
import 'package:stockwiki/pages/ai_stock_recommend_page.dart';
import 'package:stockwiki/widgets/stock_card.dart';
import 'package:stockwiki/models/stock.dart';

void main() {
  // 캐시 무효화를 위한 설정
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockWiki',
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'NotoSansKR',
        ),
      ),
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
  List<Stock> _usStocks = []; // 미국 주식 객체 저장용
  bool _isLoading = false;
  String _marketType = 'us';
  bool _showWidgets = true;

  void _refresh() {
    setState(() {
      _controller.clear();
      _results.clear();
      _krResults.clear();
      _usStocks.clear();
      _isLoading = false;
      _showWidgets = true;
    });
  }

  String? _validateKeyword(String keyword) {
    final trimmed = keyword.trim();
    
    // 빈 검색어만 체크, 나머지는 모두 허용
    if (trimmed.isEmpty) {
      return '검색어를 입력해주세요';
    }
    
    return null; // 모든 검색어 허용
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
      _usStocks.clear();
      _showWidgets = false;
    });

    try {
      if (_marketType == 'us') {
        final stocks = await FMPService.fetchStocks(keyword);
        setState(() {
          _usStocks = stocks;
          _results = stocks.map((s) => '${s.name} (${s.symbol}) - \$${s.price}').toList();
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
        _usStocks = [];
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
    if (raw == null) return 'N/A';
    final str = raw.toString();
    if (str.isEmpty || str == 'null') return 'N/A';
    
    // double 값 처리
    final doubleValue = double.tryParse(str);
    if (doubleValue != null) {
      final intValue = doubleValue.toInt();
      return '₩${intValue.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
    }
    
    // int 값 처리
    final intValue = int.tryParse(str);
    if (intValue != null) {
      return '₩${intValue.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
    }
    
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Builder(
            builder: (BuildContext innerContext) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(innerContext).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            Container(
              color: Colors.grey[850],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📊 StockWiki 메뉴', style: TextStyle(fontSize: 20, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_graph, color: Colors.white),
                    title: const Text("AI 종목 추천", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiStockRecommendPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _refresh,
              child: const Center(
                child: Text('StockWiki', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
            if (_showWidgets) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: GoldWidget()),
                  SizedBox(width: 12),
                  Expanded(child: SilverWidget()),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: UsdKrwWidget()),
                  SizedBox(width: 12),
                  Expanded(child: FearGreedWidget()),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: WtiWidget()),
                  SizedBox(width: 12),
                  Expanded(child: BtcWidget()),
                ],
              ),
            ],
            const SizedBox(height: 20),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: _marketType == 'us'
                    ? _usStocks.isEmpty
                        ? const Text('')
                        : ListView.builder(
                            itemCount: _usStocks.length,
                            itemBuilder: (context, index) {
                              final stock = _usStocks[index];
                              return Card(
                                color: Colors.grey[800],
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                              );
                            },
                          )
                    : _krResults.isEmpty
                        ? const Text('')
                        : ListView.builder(
                            itemCount: _krResults.length,
                            itemBuilder: (context, index) {
                              final stock = _krResults[index];
                              // StockCard 위젯을 사용하여 차트 포함
                              return StockCard(
                                stock: Stock.fromKrxData(stock),
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
