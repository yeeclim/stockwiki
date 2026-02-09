import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import 'us_stock_detail_page.dart';
import 'us_stock_search_page.dart';
import 'ai_stock_recommend_page.dart';
import 'us_stock_ai_recommend_page.dart';
import 'us_stock_ai_committee_page.dart';
import 'ai_algorithm_explain_page.dart';
import 'bookmark_list_page.dart';
import 'theme_recommendations_page.dart';

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
  final Map<String, List<Stock>> _sectorStocks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sectors = FMPService.getAvailableSectors();
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
        final stocks = await FMPService.fetchStocksBySector(sector, limit: 10);
        setState(() {
          _sectorStocks[sector] = stocks;
        });
      }
    } catch (e) {
      debugPrint('Sector별 주식 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSector(String sector) async {
    if (_sectorStocks.containsKey(sector) && _sectorStocks[sector]!.isNotEmpty) {
      return; // 이미 로드됨
    }

    setState(() => _isLoading = true);
    try {
      final stocks = await FMPService.fetchStocksBySector(sector, limit: 10);
      setState(() {
        _sectorStocks[sector] = stocks;
        _isLoading = false;
      });
    } catch (e) {
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
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _loadAllSectors,
            tooltip: '새로고침',
          ),
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
      endDrawer: _buildMenuDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: _sectors.map((sector) {
          return _buildSectorContent(sector);
        }).toList(),
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
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ThemeRecommendationsPage()),
                    );
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

  Widget _buildSectorContent(String sector) {
    final theme = Theme.of(context);
    if (_isLoading && !_sectorStocks.containsKey(sector)) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    final stocks = _sectorStocks[sector] ?? [];

    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: theme.colorScheme.onSurfaceVariant, size: 48),
            const SizedBox(height: 16),
            Text(
              '해당 Sector의 주식을 찾을 수 없습니다',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadSector(sector),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSector(sector),
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: stocks.length,
        itemBuilder: (context, index) {
          final stock = stocks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: theme.cardTheme.elevation,
              color: theme.cardTheme.color,
              shape: theme.cardTheme.shape,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  stock.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      stock.symbol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (stock.price != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '\$${stock.price!.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: stock.changePercent != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: stock.changePercent! >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            stock.changePercent! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: stock.changePercent! >= 0
                                ? Colors.green
                                : Colors.red,
                            size: 20,
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
    );
  }
}

