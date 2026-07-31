import 'package:flutter/material.dart';
import '../services/fmp_service.dart';
import '../utils/tradingview_helper.dart';
import '../utils/number_format_utils.dart';
import '../widgets/portfolio_add_sheet.dart';

class UsStockAiRecommendPage extends StatefulWidget {
  const UsStockAiRecommendPage({super.key});

  @override
  State<UsStockAiRecommendPage> createState() => _UsStockAiRecommendPageState();
}

class _UsStockAiRecommendPageState extends State<UsStockAiRecommendPage> {
  List<StockRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recommendations =
          await FMPService.fetchRecommendedStocks(limit: 20);
      setState(() {
        _recommendations = recommendations;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '추천 주식을 불러올 수 없습니다: $e';
        _isLoading = false;
      });
    }
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 AI 미국 주식 추천',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (_lastUpdated != null)
              Text(
                '마지막 업데이트: ${_formatLastUpdated(_lastUpdated!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _loadRecommendations,
            tooltip: '새로고침',
          ),
        ],
      ),
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
              onPressed: _loadRecommendations,
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

    if (_recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, color: theme.colorScheme.primary, size: 48),
            const SizedBox(height: 16),
            Text(
              '추천 주식을 불러오는 중입니다',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadRecommendations,
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final rec = _recommendations[index];
          final stock = rec.stock;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: theme.cardTheme.elevation,
              color: theme.cardTheme.color,
              shape: theme.cardTheme.shape,
              child: InkWell(
                onTap: () => showChart(
                  context,
                  tvSymbol: usSymbol(stock.symbol),
                  stockName: stock.name,
                  yahooTicker: stock.symbol,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더: 이름, 심볼, AI 점수
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stock.symbol,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // AI 점수 배지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getScoreColor(rec.score).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getScoreColor(rec.score),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'AI ${rec.score.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: _getScoreColor(rec.score),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rec.action,
                                  style: TextStyle(
                                    color: _getActionColor(rec.action),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (stock.price != null) ...[
                            Text(
                              '\$${formatWithCommas(stock.price!, decimals: 2)}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                          if (stock.changePercent != null) ...[
                            Row(
                              children: [
                                Icon(
                                  stock.changePercent! >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: stock.changePercent! >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: stock.changePercent! >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 추천 이유
                      if (rec.reasons.isNotEmpty) ...[
                        Divider(color: theme.dividerColor, height: 1),
                        const SizedBox(height: 8),
                        Text(
                          '추천 이유:',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...rec.reasons.map((reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: Colors.green[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => showPortfolioAddSheet(
                              context,
                              stockCode: stock.symbol,
                              stockName: stock.name,
                              market: 'us',
                              currentPrice: stock.price,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 14,
                                    color: theme.colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text('포트폴리오 추가',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.bar_chart,
                                  size: 13, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '차트 보기',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Buy':
        return Colors.green;
      case 'Hold':
        return Colors.blue;
      case 'Watch':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
