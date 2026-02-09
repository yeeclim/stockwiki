import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/krx_loader.dart';
import 'us_stock_search_page.dart';
import 'ai_stock_recommend_page.dart';
import 'us_stock_ai_recommend_page.dart';
import 'us_stock_theme_recommend_page.dart';
import 'us_stock_ai_committee_page.dart';
import 'ai_algorithm_explain_page.dart';
import 'bookmark_list_page.dart';

class ThemeRecommendationsPage extends StatefulWidget {
  const ThemeRecommendationsPage({super.key});

  @override
  State<ThemeRecommendationsPage> createState() => _ThemeRecommendationsPageState();
}

class _ThemeRecommendationsPageState extends State<ThemeRecommendationsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _themes = [];
  final Map<String, List<Map<String, dynamic>>> _themeRecommendations = {};
  List<Map<String, dynamic>> _topRecommendations = [];
  List<Map<String, dynamic>> _safeRecommendations = [];
  bool _isLoading = false;
  String _selectedSortBy = 'totalScore';

  @override
  void initState() {
    super.initState();
    _themes = KrxLoader.getThemes().take(5).toList(); // 상위 5개 테마만 표시
    _tabController = TabController(length: _themes.length + 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 전체 추천 종목 로드
      _topRecommendations = KrxLoader.getTopRecommendations(limit: 10, sortBy: _selectedSortBy);

      // 안전 테마 추천 종목 로드
      _safeRecommendations = KrxLoader.getRecommendationsByRisk('low', limit: 10, sortBy: _selectedSortBy);

      // 각 테마별 추천 종목 로드
      for (String theme in _themes) {
        _themeRecommendations[theme] = KrxLoader.getThemeRecommendations(
          theme,
          limit: 5,
          sortBy: _selectedSortBy,
        );
      }
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSortChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedSortBy = value;
      });
      _loadData();
    }
  }

  void _navigateToStockDetail(String symbol) {
    // Yahoo Finance 한국 주식 페이지로 이동
    String yahooUrl;
    
    // KOSPI는 .KS, KOSDAQ은 .KQ 형식 사용
    if (symbol.length == 6) {
      // KOSPI는 보통 000000~099999, KOSDAQ은 100000~999999 범위
      int code = int.tryParse(symbol) ?? 0;
      if (code < 100000) {
        // KOSPI (000000~099999)
        yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KS';
      } else {
        // KOSDAQ (100000~999999)
        yahooUrl = 'https://finance.yahoo.com/quote/$symbol.KQ';
      }
    } else {
      yahooUrl = 'https://finance.yahoo.com/quote/$symbol';
    }
    
    // URL 열기
    _launchURL(yahooUrl);
  }

  void _launchURL(String url) async {
    try {
      // url_launcher 패키지 사용
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

  String _getRecommendationReason(Map<String, dynamic> stock, String theme) {
    final totalScore = stock['totalScore'] as int;
    final technicalScore = stock['technicalScore'] as int;
    final fundamentalScore = stock['fundamentalScore'] as int;
    final marketCap = stock['marketCap'] as int;
    final volumeTrend = stock['volumeTrend'] as String;
    
    List<String> reasons = [];
    
    // 점수 기반 추천 사유
    if (totalScore >= 80) {
      reasons.add('종합 점수 우수');
    }
    if (technicalScore >= 80) {
      reasons.add('기술적 분석 양호');
    }
    if (fundamentalScore >= 80) {
      reasons.add('기업 가치 평가 우수');
    }
    
    // 시가총액 기반
    if (marketCap >= 1000000000000) { // 1조원 이상
      reasons.add('대형주 안정성');
    } else if (marketCap >= 100000000000) { // 1000억원 이상
      reasons.add('중형주 성장성');
    } else {
      reasons.add('소형주 성장 잠재력');
    }
    
    // 거래량 기반
    if (volumeTrend == '증가') {
      reasons.add('거래량 증가로 관심도 상승');
    }
    
    // 테마별 특화 사유
    switch (theme) {
      case '안전':
        // 안전 테마는 대형주 중심의 안정적인 종목
        if (marketCap >= 50000000000000) { // 5조원 이상
          reasons.add('대형주 안정성');
        }
        if (fundamentalScore >= 70) {
          reasons.add('재무 건전성 우수');
        }
        reasons.add('리스크 낮은 안전 투자');
        break;
      case 'AI':
        reasons.add('AI 기술 발전과 시장 확대');
        break;
      case '반도체':
        reasons.add('글로벌 반도체 수요 증가');
        break;
      case '바이오':
        reasons.add('신약 개발 및 의료 기술 혁신');
        break;
      case '배터리':
        reasons.add('전기차 시장 성장과 배터리 수요');
        break;
      case '로봇':
        reasons.add('자동화 및 로봇 기술 발전');
        break;
    }
    
    return reasons.isNotEmpty ? reasons.take(3).join(', ') : '종합적 분석 결과';
  }

  String _getHoldingPeriod(Map<String, dynamic> stock, String theme) {
    final totalScore = stock['totalScore'] as int;
    final marketCap = stock['marketCap'] as int;
    final symbol = stock['symbol'] as String;
    
    // 종목별 고유성을 위해 symbol 해시값 사용
    final symbolHash = symbol.hashCode.abs();
    
    // 점수와 시가총액을 종합하여 보유 기간 결정
    int baseMonths = 3;
    
    if (totalScore >= 90) {
      baseMonths = 12; // 1년
    } else if (totalScore >= 80) {
      baseMonths = 9; // 9개월
    } else if (totalScore >= 70) {
      baseMonths = 6; // 6개월
    } else if (totalScore >= 60) {
      baseMonths = 3; // 3개월
    } else {
      baseMonths = 1; // 1개월
    }
    
    // 대형주는 더 긴 보유 기간
    if (marketCap >= 1000000000000) { // 1조원 이상
      baseMonths = (baseMonths * 1.5).round();
    }
    
    // 테마별 조정 (실제 테마명 사용)
    switch (theme) {
      case '안전':
        baseMonths = (baseMonths * 1.3).round(); // 안정적인 대형주는 장기 보유
        break;
      case 'AI':
        baseMonths = (baseMonths * 1.2).round(); // 장기 성장 테마
        break;
      case '반도체장비':
        baseMonths = (baseMonths * 1.2).round(); // 장기 성장 테마
        break;
      case '바이오':
        baseMonths = (baseMonths * 1.5).round(); // 매우 장기적
        break;
      case '2차전지':
        baseMonths = (baseMonths * 1.1).round(); // 중장기
        break;
      case '전기차':
        baseMonths = (baseMonths * 1.1).round(); // 중장기
        break;
      case '수소차':
        baseMonths = (baseMonths * 1.1).round(); // 중장기
        break;
      case '자동차부품':
        baseMonths = (baseMonths * 1.0).round(); // 단기
        break;
      case '의료기기':
        baseMonths = (baseMonths * 1.3).round(); // 장기
        break;
      case '방산주':
        baseMonths = (baseMonths * 1.4).round(); // 매우 장기
        break;
      case '밸류업':
        baseMonths = (baseMonths * 1.0).round(); // 단기
        break;
    }
    
    // 종목별 고유성 추가 (symbol 해시값 기반)
    final variation = (symbolHash % 6) - 2; // -2 ~ +3 개월 변동
    baseMonths = (baseMonths + variation).clamp(1, 24); // 1~24개월 범위
    
    return '${baseMonths}개월';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '테마별 추천 종목',
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: theme.textTheme.labelMedium,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            const Tab(text: '전체'),
            const Tab(text: '안전'),
            ..._themes.map((themeName) => Tab(text: themeName.length > 4 ? themeName.substring(0, 4) : themeName)),
          ],
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
      endDrawer: _buildMenuDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTopRecommendations(),
                _buildSafeRecommendations(),
                ..._themes.map((theme) => _buildThemeRecommendations(theme)),
              ],
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
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsStockThemeRecommendPage()),
                    );
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

  Widget _buildTopRecommendations() {
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topRecommendations.length,
            itemBuilder: (context, index) {
              final stock = _topRecommendations[index];
              return _buildRecommendationCard(stock, index + 1, '전체');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSafeRecommendations() {
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _safeRecommendations.length,
            itemBuilder: (context, index) {
              final stock = _safeRecommendations[index];
              return _buildRecommendationCard(stock, index + 1, '안전');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThemeRecommendations(String theme) {
    final stocks = _themeRecommendations[theme] ?? [];
    
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: stocks.isEmpty
              ? const Center(child: Text('해당 테마의 추천 종목이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return _buildRecommendationCard(stock, index + 1, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('종합 점수', 'totalScore'),
                  _buildChip('기술적 점수', 'technicalScore'),
                  _buildChip('펀더멘털 점수', 'fundamentalScore'),
                  _buildChip('시가총액', 'marketCap'),
                  _buildChip('거래량', 'volume'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _selectedSortBy == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) => _onSortChanged(value),
        selectedColor: theme.colorScheme.primary,
        checkmarkColor: theme.colorScheme.onPrimary,
        backgroundColor: theme.colorScheme.surfaceVariant,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> stock, int rank, String theme) {
    final themeData = Theme.of(context);
    final recommendation = stock['recommendation'] as String;
    final totalScore = stock['totalScore'] as int;
    final technicalScore = stock['technicalScore'] as int;
    final fundamentalScore = stock['fundamentalScore'] as int;
    final trend = stock['trend'] as String;
    final volumeTrend = stock['volumeTrend'] as String;
    final marketCap = stock['marketCap'] as int;
    final symbol = stock['symbol'] as String;

    Color getRecommendationColor() {
      switch (recommendation) {
        case '강력매수':
          return Colors.red[800]!;
        case '매수':
          return Colors.red[600]!;
        case '약한매수':
          return Colors.orange[600]!;
        case '관망':
          return Colors.grey[600]!;
        case '약한매도':
          return Colors.blue[600]!;
        case '매도':
          return Colors.blue[800]!;
        case '강력매도':
          return Colors.blue[900]!;
        default:
          return Colors.grey[600]!;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: themeData.cardTheme.elevation,
      color: themeData.cardTheme.color,
      shape: themeData.cardTheme.shape,
      child: InkWell(
        onTap: () => _navigateToStockDetail(symbol),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: getRecommendationColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock['name'] as String,
                          style: themeData.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: themeData.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${stock['symbol']} • ${stock['sector']}',
                          style: themeData.textTheme.bodySmall?.copyWith(
                            color: themeData.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (stock['themes'] != null && (stock['themes'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: (stock['themes'] as List<String>).take(3).map((theme) => 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: themeData.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    theme,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: themeData.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: getRecommendationColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: getRecommendationColor()),
                    ),
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        color: getRecommendationColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildScoreItem('종합', totalScore, Colors.blue),
                  ),
                  Expanded(
                    child: _buildScoreItem('기술적', technicalScore, Colors.green),
                  ),
                  Expanded(
                    child: _buildScoreItem('펀더멘털', fundamentalScore, Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem('추세', trend),
                  ),
                  Expanded(
                    child: _buildInfoItem('거래량', volumeTrend),
                  ),
                  Expanded(
                    child: _buildInfoItem('시가총액', '${(marketCap / 1000000000000).toStringAsFixed(1)}조원'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: themeData.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '추천 사유',
                          style: themeData.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: themeData.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRecommendationReason(stock, theme),
                      style: themeData.textTheme.bodySmall?.copyWith(
                        color: themeData.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '권장 보유 기간: ',
                          style: themeData.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          _getHoldingPeriod(stock, theme),
                          style: themeData.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, int score, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 1),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 0),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 10,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
