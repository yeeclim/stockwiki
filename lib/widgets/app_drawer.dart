import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockwiki/main.dart' show themeNotifier;
import 'package:stockwiki/providers/auth_provider.dart';
import 'package:stockwiki/services/auth_service.dart';
import '../pages/us_stock_search_page.dart';
import '../pages/ai_stock_recommend_page.dart';
import '../pages/us_stock_ai_recommend_page.dart';
import '../pages/us_stock_theme_recommend_page.dart';
import '../pages/us_stock_ai_committee_page.dart';
import '../pages/theme_recommendations_page.dart';
import '../pages/bookmark_list_page.dart';
import '../pages/portfolio_page.dart';
import '../pages/kr_stock_search_page.dart';
import '../pages/board_page.dart';
import '../pages/login_page.dart';
import '../pages/ai_trading_page.dart';
import '../pages/my_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.isLoggedIn;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
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
                        ) ??
                        const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).maybePop(),
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
                // ── 마이페이지 ────────────────────────────────────────────
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    backgroundImage: isLoggedIn && authProvider.avatarUrl != null
                        ? NetworkImage(authProvider.avatarUrl!)
                        : null,
                    child: !isLoggedIn || authProvider.avatarUrl == null
                        ? Icon(Icons.person,
                            size: 18, color: theme.colorScheme.primary)
                        : null,
                  ),
                  title: Text(
                    '마이페이지',
                    style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold) ??
                        TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    isLoggedIn
                        ? authProvider.displayName
                        : '로그인 / 회원가입',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isLoggedIn) {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyPage()));
                    } else {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()));
                    }
                  },
                ),

                Divider(color: theme.dividerColor, height: 1),

                // ── 설정 ──────────────────────────────────────────────────
                _sectionLabel(context, theme, '설정'),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentMode, child) {
                    return SwitchListTile(
                      title: Text('다크 모드',
                          style: theme.textTheme.bodyLarge ??
                              TextStyle(color: theme.colorScheme.onSurface)),
                      secondary:
                          Icon(Icons.dark_mode, color: theme.colorScheme.onSurface),
                      value: currentMode == ThemeMode.dark,
                      onChanged: (val) {
                        themeNotifier.value =
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),

                Divider(color: theme.dividerColor, height: 1),

                // ── AI 매매 (로그인한 경우만) ────────────────────────────
                if (isLoggedIn) ...[
                  _sectionLabel(context, theme, 'AI 매매'),
                  ListTile(
                    leading:
                        const Icon(Icons.smart_toy, color: Colors.deepOrange),
                    title: Text('AI 자동매매',
                        style: theme.textTheme.bodyLarge ??
                            TextStyle(color: theme.colorScheme.onSurface)),
                    subtitle: Text(
                      'KIS API 설정 · 전략 안내',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiTradingPage()),
                      );
                    },
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                ],

                // ── 공통 ──────────────────────────────────────────────────
                _sectionLabel(context, theme, '공통'),
                ListTile(
                  leading: Icon(Icons.star, color: Colors.amber.shade600),
                  title: Text('관심종목',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text('국내·미국 즐겨찾기',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BookmarkListPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Colors.deepPurple),
                  title: Text('내 포트폴리오',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text('보유 종목 · 수익률 추적',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PortfolioPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups, color: Colors.green),
                  title: Text('AI 검증위원회',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text('다중 AI 검증',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UsStockAiCommitteePage()));
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.forum_outlined, color: Colors.orange),
                  title: Text('자유게시판',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text('익명 자유 토론',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BoardPage()));
                  },
                ),

                Divider(color: theme.dividerColor, height: 1),

                // ── 한국 주식 ─────────────────────────────────────────────
                _sectionLabel(context, theme, '한국 주식'),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.blue),
                  title: Text('국내 검색',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  subtitle: Text('국내 주식·ETF·ETN',
                      style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const KrStockSearchPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.blue),
                  title: Text('AI 종목 추천',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AiStockRecommendPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.blue),
                  title: Text('테마별 추천 종목',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ThemeRecommendationsPage()));
                  },
                ),

                Divider(color: theme.dividerColor, height: 1),

                // ── 미국 주식 ─────────────────────────────────────────────
                _sectionLabel(context, theme, '미국 주식'),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.green),
                  title: Text('주식 검색',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UsStockSearchPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_graph, color: Colors.green),
                  title: Text('AI 종목 추천',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UsStockAiRecommendPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: Text('Sector별 추천 종목',
                      style: theme.textTheme.bodyLarge ??
                          TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UsStockThemeRecommendPage()));
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

  Widget _sectionLabel(
      BuildContext context, ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ) ??
            TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

// (더 이상 사용하지 않는 타일 — 마이페이지 ListTile로 대체됨)
// ignore: unused_element
class _LoginTile extends StatelessWidget {
  final ThemeData theme;
  const _LoginTile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginPage()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha:0.12),
              child:
                  Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('로그인 / 회원가입',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold)),
                  Text('AI 자동매매 기능을 이용하세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _UserTile extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeData theme;
  const _UserTile({required this.authProvider, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha:0.15),
            backgroundImage: authProvider.avatarUrl != null
                ? NetworkImage(authProvider.avatarUrl!)
                : null,
            child: authProvider.avatarUrl == null
                ? Icon(Icons.person,
                    color: theme.colorScheme.primary, size: 20)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authProvider.displayName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (authProvider.currentUser?.email != null &&
                    authProvider.displayName != authProvider.currentUser?.email)
                  Text(authProvider.currentUser!.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: Icon(Icons.logout,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
        ],
      ),
    );
  }
}
