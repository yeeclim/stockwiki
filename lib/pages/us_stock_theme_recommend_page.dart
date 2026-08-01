import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stock.dart';
import '../services/us_sector_loader.dart';
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
  late TabController _tabController;
  List<String> _sectors = [];
  final Map<String, List<Map<String, dynamic>>> _sectorStocks = {};
  @override
  void initState() {
    super.initState();
    _sectors = UsSectorLoader.getSectors();
    _tabController = TabController(length: _sectors.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAllSectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSectors() async {
    try {
      for (String sector in _sectors) {
        _sectorStocks[sector] = UsSectorLoader.getSectorStocks(sector);
      }
    } catch (e) {
      debugPrint('Sector별 주식 로드 오류: $e');
    }
    if (mounted) setState(() {});
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

  void _showSectorPickerSheet() {
    final theme = Theme.of(context);
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
                      final isSelected = _tabController.index == index;
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
                          _tabController.animateTo(index);
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

  void _navigateToStockDetail(String symbol, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsStockDetailPage(
          stock: Stock(symbol: symbol, name: name),
        ),
      ),
    );
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
        title: GestureDetector(
          onTap: _showSectorPickerSheet,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sectors.isNotEmpty
                    ? '${_getSectorIcon(_sectors[_tabController.index])} ${_sectors[_tabController.index]}'
                    : '📊 Sector별 추천 종목',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface, size: 20),
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
    final reason = stock['reason'] as String? ??
        'Key sector leader with strong fundamentals.';

    // 뉴스 데이터 타입 변경 대응 (List<Map<String, String>>)
    final newsList =
        (stock['news'] as List<dynamic>? ?? []).cast<Map<String, String>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: themeData.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeData.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _navigateToStockDetail(symbol, name),
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
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: themeData.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),

              // 추천 사유 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          themeData.colorScheme.primary.withValues(alpha: 0.2)),
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
                    Icon(Icons.article_outlined,
                        size: 16, color: themeData.colorScheme.secondary),
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
                          Text('• ',
                              style: TextStyle(
                                  color:
                                      themeData.colorScheme.onSurfaceVariant)),
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
}
