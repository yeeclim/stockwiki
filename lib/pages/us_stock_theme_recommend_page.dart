import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/us_sector_loader.dart';
import '../utils/number_format_utils.dart';
import '../widgets/app_drawer.dart';
import 'us_stock_detail_page.dart';

class UsStockThemeRecommendPage extends StatefulWidget {
  const UsStockThemeRecommendPage({super.key});

  @override
  State<UsStockThemeRecommendPage> createState() =>
      _UsStockThemeRecommendPageState();
}

class _UsStockThemeRecommendPageState extends State<UsStockThemeRecommendPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<String> _sectors = [];
  final Map<String, List<Map<String, dynamic>>> _sectorStocks = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final grouped = await UsSectorLoader.loadAll();
      // 종목이 있는 섹터만 탭으로 노출
      final nonEmpty = grouped.entries.where((e) => e.value.isNotEmpty);

      _sectorStocks.clear();
      for (final entry in nonEmpty) {
        _sectorStocks[entry.key] = entry.value;
      }

      final oldController = _tabController;
      final sectors = _sectorStocks.keys.toList();

      if (mounted) {
        setState(() {
          _sectors = sectors;
          _tabController = sectors.isNotEmpty
              ? TabController(length: sectors.length, vsync: this)
              : null;
          _tabController?.addListener(() {
            if (mounted) setState(() {});
          });
          _isLoading = false;
        });
        oldController?.dispose();
      }
    } catch (e) {
      debugPrint('Sector별 추천 종목 로드 오류: $e');
      if (mounted) {
        setState(() {
          _error = '섹터별 추천 종목을 불러올 수 없습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getSectorIcon(String sector) {
    switch (sector) {
      case 'Technology':
        return '💻';
      case 'Healthcare':
        return '🏥';
      case 'Financial Services':
        return '💰';
      case 'Consumer Cyclical':
        return '🛍️';
      case 'Consumer Defensive':
        return '🛒';
      case 'Energy':
        return '⚡';
      case 'Industrials':
        return '🏭';
      case 'Basic Materials':
        return '⛏️';
      case 'Utilities':
        return '🔌';
      case 'Real Estate':
        return '🏢';
      case 'Communication Services':
        return '📡';
      default:
        return '📊';
    }
  }

  void _showSectorPickerSheet() {
    final theme = Theme.of(context);
    final tabController = _tabController;
    if (tabController == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('섹터 선택',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _sectors.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4)),
                    itemBuilder: (_, index) {
                      final isSelected = tabController.index == index;
                      return ListTile(
                        dense: true,
                        leading: Text(_getSectorIcon(_sectors[index]),
                            style: const TextStyle(fontSize: 18)),
                        title: Text(
                          _sectors[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                size: 16, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          tabController.animateTo(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToStockDetail(String symbol, String name, {double? price}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsStockDetailPage(
          stock: Stock(symbol: symbol, name: name, price: price),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabController = _tabController;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: GestureDetector(
          onTap: tabController != null ? _showSectorPickerSheet : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sectors.isNotEmpty && tabController != null
                    ? '${_getSectorIcon(_sectors[tabController.index])} ${_sectors[tabController.index]}'
                    : '📊 Sector별 추천 종목',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (tabController != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurface, size: 20),
              ],
            ],
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
        bottom: tabController == null
            ? null
            : TabBar(
                controller: tabController,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
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

    final tabController = _tabController;
    if (_sectors.isEmpty || tabController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, color: theme.colorScheme.primary, size: 48),
            const SizedBox(height: 16),
            Text(
              '섹터별 추천 종목이 없습니다',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadData,
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: tabController,
      children: _sectors.map((sector) => _buildSectorContent(sector)).toList(),
    );
  }

  Widget _buildSectorContent(String sector) {
    final stocks = _sectorStocks[sector] ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: stocks.length,
        itemBuilder: (context, index) {
          final stock = stocks[index];
          return _buildRecommendationCard(stock);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> stock) {
    final themeData = Theme.of(context);
    final symbol = stock['symbol'] as String;
    final name = stock['name'] as String;
    final exchange = stock['exchange'] as String? ?? '';
    final price = (stock['price'] as num?)?.toDouble();
    final changePercent = (stock['changePercent'] as num?)?.toDouble() ?? 0;
    final score = (stock['score'] as num?)?.toDouble() ?? 0;
    final action = stock['action'] as String? ?? 'Hold';
    final reasons = (stock['reasons'] as List<dynamic>? ?? []).cast<String>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: themeData.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeData.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _navigateToStockDetail(symbol, name, price: price),
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
                          '$symbol${exchange.isNotEmpty ? ' • $exchange' : ''}',
                          style: themeData.textTheme.bodySmall?.copyWith(
                            color: themeData.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 점수 배지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getScoreColor(score).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getScoreColor(score)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            color: _getScoreColor(score),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action,
                          style: TextStyle(
                            color: _getActionColor(action),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 가격 정보
              if (price != null)
                Row(
                  children: [
                    Text(
                      '\$${formatWithCommas(price, decimals: 2)}',
                      style: themeData.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeData.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      changePercent >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: changePercent >= 0 ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                      style: themeData.textTheme.titleSmall?.copyWith(
                        color: changePercent >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeData.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: themeData.colorScheme.primary
                            .withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb,
                              size: 16, color: themeData.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '추천 이유',
                            style: themeData.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeData.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...reasons.map((reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: themeData
                                            .colorScheme.onSurfaceVariant)),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style:
                                        themeData.textTheme.bodySmall?.copyWith(
                                      color: themeData
                                          .colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // 차트 보기 힌트
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.bar_chart,
                      size: 13, color: themeData.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '차트 보기',
                    style: themeData.textTheme.labelSmall?.copyWith(
                      color: themeData.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // score는 10점 만점 (BUY_THRESHOLD=6 이상만 API가 반환)
  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.blue;
    return Colors.orange;
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Buy':
        return Colors.green;
      case 'Watch':
        return Colors.orange;
      case 'Hold':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
