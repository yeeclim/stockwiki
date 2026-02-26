import 'package:flutter/material.dart';
import 'package:stockwiki/theme/app_theme.dart';
import 'package:stockwiki/widgets/fear_greed_widget.dart';
import 'package:stockwiki/widgets/usdkrw_widget.dart';
import 'package:stockwiki/widgets/gold_widget.dart';
import 'package:stockwiki/widgets/silver_widget.dart';
import 'package:stockwiki/widgets/wti_widget.dart';
import 'package:stockwiki/widgets/btc_widget.dart';
import 'package:stockwiki/pages/us_stock_search_page.dart';
import 'package:stockwiki/pages/ai_stock_recommend_page.dart';
import 'package:stockwiki/pages/theme_recommendations_page.dart';
import 'package:stockwiki/pages/ai_algorithm_explain_page.dart';
import 'package:stockwiki/pages/bookmark_list_page.dart';
import 'package:stockwiki/pages/us_stock_ai_recommend_page.dart';
import 'package:stockwiki/pages/us_stock_theme_recommend_page.dart';
import 'package:stockwiki/pages/us_stock_ai_committee_page.dart';

// Global Theme Notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'StockWiki',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const StockSearchPage(),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StockWiki',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
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
      endDrawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📊 메뉴',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 테마 설정
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '설정',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      "다크 모드",
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    secondary: Icon(
                      Icons.dark_mode,
                      color: theme.colorScheme.onSurface,
                    ),
                    value: themeNotifier.value == ThemeMode.dark,
                    onChanged: (val) {
                      themeNotifier.value =
                          val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),

                  Divider(height: 1, color: theme.dividerColor),

                  // 공통 기능 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '공통',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups, color: Colors.green),
                    title: Text("AI 검증위원회", style: TextStyle(color: theme.colorScheme.onSurface)),
                    subtitle: Text(
                      '다중 AI 검증',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockAiCommitteePage()),
                      );
                    },
                  ),
                  Divider(height: 1, color: theme.dividerColor),

                  // 한국 주식 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '🇰🇷 한국 주식',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_graph, color: Colors.blue),
                    title: Text("AI 종목 추천", style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiStockRecommendPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.blue),
                    title: Text("테마별 추천 종목", style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemeRecommendationsPage()),
                      );
                    },
                  ),

                  Divider(height: 1, color: theme.dividerColor),

                  // 미국 주식 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '🇺🇸 미국 주식',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.green),
                    title: Text("주식 검색", style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockSearchPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_graph, color: Colors.green),
                    title: Text("AI 종목 추천", style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockAiRecommendPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: Text("Sector별 추천 종목", style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsStockThemeRecommendPage()),
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
              // 헤더 섹션 (App Bar로 이동했으므로 제거하거나 환영 메시지로 변경)
              const SizedBox(height: 30),

              // 주요 기능 버튼 (디자인 개선)
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
                        '테마별 추천 종목 확인하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 금융 상품 섹션
              if (_showWidgets) ...[
                _buildSectionTitle(context, '금융 상품'),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: GoldWidget()),
                    SizedBox(width: 16),
                    Expanded(child: SilverWidget()),
                  ],
                ),
                const SizedBox(height: 32),

                // 시장 지표 섹션
                _buildSectionTitle(context, '시장 지표'),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: UsdKrwWidget()),
                    SizedBox(width: 16),
                    Expanded(child: FearGreedWidget()),
                  ],
                ),
                const SizedBox(height: 32),

                // 에너지 섹션
                _buildSectionTitle(context, '에너지'),
                const SizedBox(height: 16),
                const WtiWidget(),
                const SizedBox(height: 32),

                // 암호화폐 섹션
                _buildSectionTitle(context, '암호화폐'),
                const SizedBox(height: 16),
                const BtcWidget(),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
