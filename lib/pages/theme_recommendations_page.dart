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
import '../widgets/app_drawer.dart';

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
    _initThemesAndController();
  }

  Future<void> _initThemesAndController() async {
    setState(() => _isLoading = true);
    try {
      final themes = await KrxLoader.getThemes();
      if (mounted) {
        setState(() {
          _themes = themes;
          if (_themes.isNotEmpty) {
            _tabController = TabController(length: _themes.length, vsync: this);
          }
        });
        if (_themes.isNotEmpty) {
          _loadData();
        } else {
           setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('테마 초기화 오류: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (_themes.isNotEmpty) _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_themes.isEmpty) return;
    
    setState(() => _isLoading = true);

    try {
      // 현재 선택된 탭의 데이터 우선 로드 또는 모든 탭 로드
      // 성능을 위해 현재는 모든 탭 순차 로드 (기존 로직 유지)
      for (String theme in _themes) {
        final stocks = await KrxLoader.getThemeStocks(theme);
        if (mounted) {
          setState(() {
            _themeStocks[theme] = stocks;
          });
        }
      }
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToStockDetail(String symbol) {
    // Yahoo Finance 한국 주식 페이지로 이동
    // 0/1/2/3/4/5 로 시작하는 종목은 유가증권(KS), 나머지는 코스닥(KQ) 확률이 높지만
    // 네이버에서 가져올 때 마켓 정보를 주면 더 정확함. 현재는 기존 하드코딩 + 휴리스틱 유지
    String yahooUrl;
     
     // 간단한 마켓 구분 (6자리 숫자인 경우)
     if (symbol.length == 6) {
       // 코스닥 종목 예외 처리 (기존 리스트 유지 및 신규 추가 대응)
       final kosdaqStocks = ['247540', '095610', '240810', '035720', '068270', '086520', '196170', '357780']; 
       if (kosdaqStocks.contains(symbol)) {
         yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KQ';
       } else {
         yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KS';
       }
     } else {
       yahooUrl = 'https://finance.yahoo.com/quote/$symbol';
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
    
    // 테마가 아직 로드되지 않았을 때의 처리
    if (_themes.isEmpty && _isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('📈 테마별 추천 종목')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '📈 테마별 추천 종목',
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
        bottom: _themes.isEmpty 
          ? null 
          : TabBar(
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
      endDrawer: const AppDrawer(),
      body: _themes.isEmpty
          ? Center(child: Text(_isLoading ? '데이터를 불러오는 중...' : '추천 테마가 없습니다.'))
          : TabBarView(
              controller: _tabController,
              children: _themes.map((theme) => _buildThemeRecommendations(theme)).toList(),
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
