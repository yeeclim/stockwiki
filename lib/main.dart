import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stockwiki/providers/auth_provider.dart';
import 'utils/pkce_storage.dart'
    if (dart.library.js_interop) 'utils/pkce_storage_web.dart';
import 'package:stockwiki/providers/bookmark_provider.dart';
import 'package:stockwiki/theme/app_theme.dart';
import 'package:stockwiki/widgets/fear_greed_widget.dart';
import 'package:stockwiki/widgets/usdkrw_widget.dart';
import 'package:stockwiki/widgets/gold_widget.dart';
import 'package:stockwiki/widgets/silver_widget.dart';
import 'package:stockwiki/widgets/wti_widget.dart';
import 'package:stockwiki/widgets/btc_widget.dart';
import 'package:stockwiki/pages/theme_recommendations_page.dart';
import 'package:stockwiki/widgets/app_drawer.dart';
import 'package:stockwiki/widgets/terminal_grid.dart';
import 'package:stockwiki/widgets/hover_lift.dart';
import 'package:stockwiki/widgets/btc_sparkline_widget.dart';

// Global Theme Notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

// Supabase 설정 (--dart-define 으로 주입)
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://xpiqctjidvrlmazslzyg.supabase.co');
const _supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    debug: true,
    authOptions: FlutterAuthClientOptions(
      pkceAsyncStorage: createPkceStorage(),
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookmarkProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
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

class _StockSearchPageState extends State<StockSearchPage>
    with SingleTickerProviderStateMixin {
  bool _showWidgets = true;
  late final AnimationController _liveDotController;

  @override
  void initState() {
    super.initState();
    _liveDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _liveDotController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _showWidgets = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final market = theme.extension<MarketColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: market.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.35).animate(_liveDotController),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: market.up,
                  boxShadow: [
                    BoxShadow(
                        color: market.up.withValues(alpha: 0.6), blurRadius: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'STOCKWIKI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 15,
                color: market.ink,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: market.bg,
        elevation: 0,
        actions: [
          Builder(
            builder: (BuildContext innerContext) {
              return IconButton(
                icon: Icon(Icons.menu, color: market.muted),
                onPressed: () {
                  Scaffold.of(innerContext).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
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
              // 주요 기능 CTA — 네온/에메랄드 테두리 글로우 버튼
              HoverLift(
                borderRadius: BorderRadius.circular(3),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ThemeRecommendationsPage()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: market.surface,
                      border: Border.all(color: market.accent),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                  color: market.accentDim, blurRadius: 18),
                            ]
                          : const [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '테마별 추천 종목 확인하기',
                          style: TextStyle(
                            color: market.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('→',
                            style: TextStyle(
                                color: market.accent,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              if (_showWidgets) ...[
                _buildSectionTitle(market, '금융 상품'),
                const SizedBox(height: 12),
                const TerminalGrid(children: [GoldWidget(), SilverWidget()]),
                const SizedBox(height: 28),
                _buildSectionTitle(market, '시장 지표'),
                const SizedBox(height: 12),
                const TerminalGrid(children: [UsdKrwWidget()]),
                const SizedBox(height: 10),
                const FearGreedWidget(),
                const SizedBox(height: 28),
                _buildSectionTitle(market, '에너지'),
                const SizedBox(height: 12),
                const TerminalGrid(children: [WtiWidget()]),
                const SizedBox(height: 28),
                _buildSectionTitle(market, '암호화폐'),
                const SizedBox(height: 12),
                const TerminalGrid(
                    children: [BtcWidget(), BtcSparklineWidget()]),
                const SizedBox(height: 36),
              ],

              // 푸터
              Divider(color: market.line),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Made by Bermont',
                      style: TextStyle(
                        fontSize: 12,
                        color: market.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '본 서비스의 모든 투자 판단 및 그 결과에 대한\n책임은 전적으로 이용자 본인에게 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: market.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(MarketColors market, String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: market.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: market.muted,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
