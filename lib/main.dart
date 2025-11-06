// 📄 lib/main.dart
import 'package:flutter/material.dart';
import 'package:stockwiki/widgets/fear_greed_widget.dart';
import 'package:stockwiki/widgets/usdkrw_widget.dart';
import 'package:stockwiki/widgets/gold_widget.dart';
import 'package:stockwiki/widgets/silver_widget.dart';
import 'package:stockwiki/widgets/wti_widget.dart';
import 'package:stockwiki/widgets/btc_widget.dart';
import 'package:stockwiki/pages/interest_news_page.dart';
import 'package:stockwiki/pages/us_stock_search_page.dart';
import 'package:stockwiki/pages/ai_stock_recommend_page.dart';
import 'package:stockwiki/pages/theme_recommendations_page.dart';
import 'package:stockwiki/pages/ai_algorithm_explain_page.dart';
import 'package:stockwiki/pages/bookmark_list_page.dart';
import 'package:stockwiki/pages/us_stock_ai_recommend_page.dart';
import 'package:stockwiki/pages/us_stock_theme_recommend_page.dart';
import 'package:stockwiki/pages/us_stock_ai_committee_page.dart';

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
  bool _showWidgets = true;

  void _refresh() {
    setState(() {
      _showWidgets = true;
    });
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
                  // 공통 기능 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '공통',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology, color: Colors.white),
                    title: const Text("알고리즘 설명", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiAlgorithmExplainPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline, color: Colors.white),
                    title: const Text("북마크 목록", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BookmarkListPage()),
                      );
                    },
                  ),
                  
                  // 구분선
                  Divider(color: Colors.grey[800], height: 1),
                  
                  // 한국 주식 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '🇰🇷 한국 주식',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_graph, color: Colors.blue),
                    title: const Text("AI 종목 추천", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiStockRecommendPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.blue),
                    title: const Text("테마별 추천 종목", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemeRecommendationsPage()),
                      );
                    },
                  ),
                  
                  // 구분선
                  Divider(color: Colors.grey[800], height: 1),
                  
                  // 미국 주식 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '🇺🇸 미국 주식',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.green),
                    title: const Text("주식 검색", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockSearchPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_graph, color: Colors.green),
                    title: const Text("AI 종목 추천", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockAiRecommendPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text("Sector별 추천 종목", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockThemeRecommendPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups, color: Colors.green),
                    title: const Text("AI 검증위원회", style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '다중 AI 검증',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // 드로어 닫기
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockAiCommitteePage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // 헤더 섹션
              Center(
                child: GestureDetector(
                  onTap: _refresh,
                  child: Column(
                    children: [
                      const Text(
                        'StockWiki',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '실시간 시장 정보',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // 주요 기능 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ThemeRecommendationsPage()),
                        );
                      },
                      icon: const Icon(Icons.trending_up),
                      label: const Text(
                        '테마별 추천 종목',
                        textAlign: TextAlign.center,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // 금융 상품 섹션
              if (_showWidgets) ...[
                Text(
                  '금융 상품',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: GoldWidget()),
                    SizedBox(width: 12),
                    Expanded(child: SilverWidget()),
                  ],
                ),
                const SizedBox(height: 20),
                // 시장 지표 섹션
                Text(
                  '시장 지표',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: UsdKrwWidget()),
                    SizedBox(width: 12),
                    Expanded(child: FearGreedWidget()),
                  ],
                ),
              const SizedBox(height: 20),
              // 에너지 섹션
              Text(
                '에너지',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 12),
              const WtiWidget(),
              const SizedBox(height: 20),
              // 암호화폐 섹션
              Text(
                '암호화폐',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 12),
              const BtcWidget(),
              const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
