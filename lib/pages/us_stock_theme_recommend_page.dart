import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/us_sector_loader.dart';
import 'us_stock_search_page.dart';
import 'ai_stock_recommend_page.dart';
import 'us_stock_ai_recommend_page.dart';
import 'us_stock_ai_committee_page.dart';
import 'ai_algorithm_explain_page.dart';
import 'bookmark_list_page.dart';
import 'theme_recommendations_page.dart';
import '../widgets/app_drawer.dart';

class UsStockThemeRecommendPage extends StatefulWidget {
  const UsStockThemeRecommendPage({super.key});

  @override
  State<UsStockThemeRecommendPage> createState() =>
      _UsStockThemeRecommendPageState();
}

class _UsStockThemeRecommendPageState extends State<UsStockThemeRecommendPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _sectors = [];
  final Map<String, List<Map<String, dynamic>>> _sectorStocks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sectors = UsSectorLoader.getSectors();
    _tabController = TabController(length: _sectors.length, vsync: this);
    _loadAllSectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSectors() async {
    setState(() => _isLoading = true);

    try {
      for (String sector in _sectors) {
        _sectorStocks[sector] = UsSectorLoader.getSectorStocks(sector);
      }
    } catch (e) {
      debugPrint('Sector별 주식 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getSectorIcon(String sector) {
    switch (sector) {
      case 'Technology':
        return '💻';
      case 'Finance':
        return '💰';
      case 'Healthcare':
        return '🏥';
      case 'Consumer':
        return '🛒';
      case 'Energy':
        return '⚡';
      case 'Industrial':
        return '🏭';
      default:
        return '📊';
    }
  }

  void _navigateToStockDetail(String symbol) {
    // Yahoo Finance 미국 주식 페이지로 이동
    final yahooUrl = 'https://finance.yahoo.com/quote/$symbol';
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
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          '📊 Sector별 추천 종목',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: _sectors.map((sector) {
            return Tab(
              text: '${_getSectorIcon(sector)} $sector',
            );
          }).toList(),
        ),
      ),
      endDrawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: _sectors.map((sector) {
          return _buildSectorContent(sector);
        }).toList(),
      ),
    );
  }


  Widget _buildSectorContent(String sector) {
    final stocks = _sectorStocks[sector] ?? [];
    
    return Column(
      children: [
        Expanded(
          child: stocks.isEmpty
              ? const Center(child: Text('해당 Sector의 추천 종목이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return _buildRecommendationCard(stock, sector);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> stock, String sector) {
    final themeData = Theme.of(context);
    final symbol = stock['symbol'] as String;
    final name = stock['name'] as String;
    final description = stock['description'] as String;
    final reason = stock['reason'] as String? ?? 'Key sector leader with strong fundamentals.';
    
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
                      '관련 뉴스',
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
                    '실시간 시세 (Yahoo Finance)',
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
