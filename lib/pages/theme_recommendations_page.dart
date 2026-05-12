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
            _tabController.addListener(() { if (mounted) setState(() {}); });
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
      // 병렬 로딩 (순차 → 동시)
      await Future.wait(
        List<String>.from(_themes).map((theme) async {
          final stocks = await KrxLoader.getThemeStocks(theme);
          if (mounted) setState(() { _themeStocks[theme] = stocks; });
        }),
      );

      // 종목이 0개인 테마 숨기기
      if (mounted) {
        final visible = _themes.where((t) => (_themeStocks[t] ?? []).isNotEmpty).toList();
        if (visible.length != _themes.length) {
          final old = _tabController;
          final newCtrl = TabController(length: visible.length, vsync: this);
          newCtrl.addListener(() { if (mounted) setState(() {}); });
          setState(() {
            _themes = visible;
            _tabController = newCtrl;
          });
          old.dispose();
        }
      }
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showThemePickerSheet() {
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                Text(
                  '테마 선택',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _themes.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                    itemBuilder: (_, index) {
                      final isSelected = _tabController.index == index;
                      return ListTile(
                        dense: true,
                        leading: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          _themes[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
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

  void _navigateToStockDetail(String symbol) {
    _launchURL('https://finance.naver.com/item/main.naver?code=$symbol');
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
        appBar: AppBar(title: const Text('테마별 추천 종목')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _themes.isNotEmpty ? _showThemePickerSheet : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _themes.isNotEmpty
                      ? _themes[_tabController.index]
                      : '📈 테마별 추천 종목',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (_themes.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface, size: 20),
              ],
            ],
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
    final reason = stock['reason'] as String? ?? '관련 테마의 대표적인 수혜주로 분석됨';
    final ma20 = stock['ma20'] as num?;
    final ma60 = stock['ma60'] as num?;
    final high52w = stock['high52w'] as num?;
    final price = (stock['price'] as num?)?.toDouble();

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
              
              // MA / 52주 고가 뱃지
              if (ma20 != null || high52w != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (ma20 != null)
                        _techBadge(
                          themeData,
                          'MA20  ${_fmtPrice(ma20)}',
                          Colors.blue,
                        ),
                      if (ma60 != null)
                        _techBadge(
                          themeData,
                          'MA60  ${_fmtPrice(ma60)}',
                          Colors.indigo,
                        ),
                      if (high52w != null && price != null)
                        _techBadge(
                          themeData,
                          '52주 고가 대비 ${(price / high52w.toDouble() * 100).toStringAsFixed(1)}%',
                          Colors.teal,
                        ),
                    ],
                  ),
                ),

              // 추천 사유 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeData.colorScheme.primary.withValues(alpha: 0.2)),
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
              
              // 네이버 증권 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '네이버 증권 바로가기',
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

  Widget _techBadge(ThemeData themeData, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: themeData.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _fmtPrice(num value) {
    return value.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }
}
