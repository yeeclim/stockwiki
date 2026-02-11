import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/krx_loader.dart';
import 'us_stock_search_page.dart';
import 'ai_stock_recommend_page.dart';
import 'us_stock_ai_recommend_page.dart';
import 'us_stock_theme_recommend_page.dart';
import 'us_stock_ai_committee_page.dart';
import 'ai_algorithm_explain_page.dart';
import 'bookmark_list_page.dart';

class ThemeRecommendationsPage extends StatefulWidget {
  const ThemeRecommendationsPage({super.key});

  @override
  State<ThemeRecommendationsPage> createState() => _ThemeRecommendationsPageState();
}

class _ThemeRecommendationsPageState extends State<ThemeRecommendationsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _themes = [];
  final Map<String, List<Map<String, dynamic>>> _themeStocks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _themes = KrxLoader.getThemes(); 
    _tabController = TabController(length: _themes.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 각 테마별 종목 로드
      for (String theme in _themes) {
        _themeStocks[theme] = KrxLoader.getThemeStocks(theme);
      }
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToStockDetail(String symbol) {
    // Yahoo Finance 한국 주식 페이지로 이동
    String yahooUrl;
     
     // 코스닥 종목 예외 처리 (하드코딩된 데이터 기준)
     final kosdaqStocks = ['247540', '095610', '240810', '035720', '068270']; 
     if (kosdaqStocks.contains(symbol)) {
       yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KQ';
     } else {
       yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KS';
     }

    _launchURL(yahooUrl);
  }

  void _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('URL을 열 수 없습니다: $url');
      }
    } catch (e) {
      debugPrint('URL 실행 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '테마별 추천 종목',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        toolbarHeight: 48, 
        iconTheme: theme.iconTheme,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: theme.textTheme.labelMedium,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: _themes.map((themeName) => Tab(text: themeName)).toList(),
        ),
        actions: [
          Builder(
            builder: (BuildContext innerContext) {
              return IconButton(
                icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
                onPressed: () {
                  Scaffold.of(innerContext).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      endDrawer: _buildMenuDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _themes.map((theme) => _buildThemeRecommendations(theme)).toList(),
            ),
    );
  }

  Widget _buildMenuDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📊 StockWiki 메뉴', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 공통 기능 섹션
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    '공통',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.psychology, color: theme.colorScheme.onSurface),
                  title: Text("알고리즘 설명", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAlgorithmExplainPage()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.bookmark_outline, color: theme.colorScheme.onSurface),
                  title: Text("북마크 목록", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookmarkListPage()),
                    );
                  },
                ),
                
                // 구분선
                Divider(color: theme.dividerColor, height: 1),
                
                // 한국 주식 섹션
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '🇰🇷 한국 주식',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.blue),
                  title: Text("AI 종목 추천", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiStockRecommendPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.blue),
                  title: Text("테마별 추천 종목", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                
                // 구분선
                Divider(color: theme.dividerColor, height: 1),
                
                // 미국 주식 섹션
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '🇺🇸 미국 주식',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.green),
                  title: Text("주식 검색", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockSearchPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.green),
                  title: Text("AI 종목 추천", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockAiRecommendPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: Text("Sector별 추천 종목", style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockThemeRecommendPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups, color: Colors.green),
                  title: Text("AI 검증위원회", style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    '다중 AI 검증',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
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
    );
  }

  Widget _buildThemeRecommendations(String theme) {
    final stocks = _themeStocks[theme] ?? [];
    
    return Column(
      children: [
        // 경고 메시지 삭제됨
        Expanded(
          child: stocks.isEmpty
              ? const Center(child: Text('해당 테마의 추천 종목이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return _buildRecommendationCard(stock, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> stock, String theme) {
    final themeData = Theme.of(context);
    final symbol = stock['symbol'] as String;
    final name = stock['name'] as String;
    final sector = stock['sector'] as String;
    final description = stock['description'] as String;
    final reason = stock['reason'] as String? ?? '관련 테마의 대표적인 수혜주로 분석됨';
    
    // 뉴스 데이터 타입 변경 대응 (List<Map<String, String>>)
    final newsList = (stock['news'] as List<dynamic>? ?? []).cast<Map<String, String>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: themeData.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeData.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _navigateToStockDetail(symbol),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: themeData.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: themeData.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$symbol • $sector',
                          style: themeData.textTheme.bodySmall?.copyWith(
                            color: themeData.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios, 
                    size: 16, 
                    color: themeData.colorScheme.onSurfaceVariant
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 기업 개요
              Text(
                description,
                style: themeData.textTheme.bodyMedium?.copyWith(
                  color: themeData.colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 추천 사유 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeData.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, size: 16, color: themeData.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '투자 포인트',
                          style: themeData.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: themeData.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: themeData.textTheme.bodySmall?.copyWith(
                        color: themeData.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              if (newsList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.article_outlined, size: 16, color: themeData.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      '관련 뉴스 (Tap to read)',
                      style: themeData.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeData.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...newsList.map((news) {
                  final title = news['title'] ?? '';
                  final url = news['url'] ?? '';
                  
                  return InkWell(
                    onTap: () => _launchURL(url),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: themeData.colorScheme.onSurfaceVariant)),
                          Expanded(
                            child: Text(
                              title,
                              style: themeData.textTheme.bodySmall?.copyWith(
                                color: Colors.blueAccent, // 링크임을 강조
                                height: 1.3,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              
              const SizedBox(height: 12),
              
              // Yahoo Finance 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Yahoo Finance 실시간 확인',
                    style: themeData.textTheme.labelSmall?.copyWith(
                      color: themeData.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new, 
                    size: 12, 
                    color: themeData.colorScheme.primary
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
