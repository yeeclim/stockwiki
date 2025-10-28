import 'package:flutter/material.dart';
import '../services/krx_loader.dart';
import '../widgets/stock_card.dart';
import '../models/stock.dart';

class ThemeRecommendationsPage extends StatefulWidget {
  const ThemeRecommendationsPage({super.key});

  @override
  State<ThemeRecommendationsPage> createState() => _ThemeRecommendationsPageState();
}

class _ThemeRecommendationsPageState extends State<ThemeRecommendationsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _themes = [];
  Map<String, List<Map<String, dynamic>>> _themeRecommendations = {};
  List<Map<String, dynamic>> _topRecommendations = [];
  bool _isLoading = false;
  String _selectedSortBy = 'totalScore';
  String _selectedRiskLevel = 'medium';

  @override
  void initState() {
    super.initState();
    _themes = KrxLoader.getThemes();
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

      // 각 테마별 추천 종목 로드
      for (String theme in _themes) {
        _themeRecommendations[theme] = KrxLoader.getThemeRecommendations(
          theme,
          limit: 5,
          sortBy: _selectedSortBy,
        );
      }
    } catch (e) {
      print('데이터 로드 오류: $e');
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

  void _onRiskLevelChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedRiskLevel = value;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테마별 추천 종목'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: '전체 추천'),
            const Tab(text: '안전 종목'),
            ..._themes.map((theme) => Tab(text: theme)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'totalScore', child: Text('종합 점수')),
              const PopupMenuItem(value: 'technicalScore', child: Text('기술적 점수')),
              const PopupMenuItem(value: 'fundamentalScore', child: Text('펀더멘털 점수')),
              const PopupMenuItem(value: 'marketCap', child: Text('시가총액')),
              const PopupMenuItem(value: 'volume', child: Text('거래량')),
            ],
            child: const Icon(Icons.sort),
          ),
        ],
      ),
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
              return _buildRecommendationCard(stock, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSafeRecommendations() {
    final safeStocks = KrxLoader.getRecommendationsByRisk('low', limit: 10);
    
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: safeStocks.length,
            itemBuilder: (context, index) {
              final stock = safeStocks[index];
              return _buildRecommendationCard(stock, index + 1);
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
                    return _buildRecommendationCard(stock, index + 1);
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
                  _buildChip('전체', 'totalScore'),
                  _buildChip('기술적', 'technicalScore'),
                  _buildChip('펀더멘털', 'fundamentalScore'),
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
    final isSelected = _selectedSortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => _onSortChanged(value),
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[800],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> stock, int rank) {
    final recommendation = stock['recommendation'] as String;
    final totalScore = stock['totalScore'] as int;
    final technicalScore = stock['technicalScore'] as int;
    final fundamentalScore = stock['fundamentalScore'] as int;
    final trend = stock['trend'] as String;
    final volumeTrend = stock['volumeTrend'] as String;
    final marketCap = stock['marketCap'] as int;

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
      elevation: 2,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${stock['symbol']} • ${stock['sector']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 0),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
