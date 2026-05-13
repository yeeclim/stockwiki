import 'package:flutter/material.dart';
import 'package:stockwiki/main.dart' show themeNotifier;
import '../pages/us_stock_search_page.dart';
import '../pages/ai_stock_recommend_page.dart';
import '../pages/us_stock_ai_recommend_page.dart';
import '../pages/us_stock_theme_recommend_page.dart';
import '../pages/us_stock_ai_committee_page.dart';
import '../pages/theme_recommendations_page.dart';
import '../pages/bookmark_list_page.dart';
import '../pages/portfolio_page.dart';
import '../pages/kr_stock_search_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'StockWiki 메뉴',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 테마 설정
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    '설정',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ) ?? TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentMode, child) {
                    return SwitchListTile(
                      title: Text(
                        "다크 모드",
                        style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      secondary: Icon(
                        Icons.dark_mode,
                        color: theme.colorScheme.onSurface,
                      ),
                      value: currentMode == ThemeMode.dark,
                      onChanged: (val) {
                        themeNotifier.value =
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
                
                // 구분선
                Divider(color: theme.dividerColor, height: 1),

                // 공통 기능 섹션
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    '공통',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ) ?? TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.star, color: Colors.amber.shade600),
                  title: Text("관심종목", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text(
                    '국내·미국 즐겨찾기',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant) ??
                           TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookmarkListPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
                  title: Text("내 포트폴리오", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text(
                    '보유 종목 · 수익률 추적',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant) ??
                           TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PortfolioPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups, color: Colors.green),
                  title: Text("AI 검증위원회", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text(
                    '다중 AI 검증',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant) ??
                           TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockAiCommitteePage()),
                    );
                  },
                ),
                
                // 구분선
                Divider(color: theme.dividerColor, height: 1),
                
                // 한국 주식 섹션
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    '한국 주식',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ) ?? TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.blue),
                  title: Text("국내 검색", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text(
                    '국내 주식·ETF·ETN',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant) ??
                           TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KrStockSearchPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.blue),
                  title: Text("AI 종목 추천", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiStockRecommendPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.blue),
                  title: Text("테마별 추천 종목", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
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
                  child: Text(
                    '미국 주식',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ) ?? TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.green),
                  title: Text("주식 검색", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockSearchPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.green),
                  title: Text("AI 종목 추천", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockAiRecommendPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: Text("Sector별 추천 종목", style: theme.textTheme.bodyLarge ?? TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockThemeRecommendPage()),
                    );
                  },
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
