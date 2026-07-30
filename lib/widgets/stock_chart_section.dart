import 'package:flutter/material.dart';

/// Displays a candlestick chart snapshot for a given stock [symbol].
///
/// Tapping the snapshot opens a full-screen dialog with period selectors
/// (1-year weekly / 3-year monthly).  All chart-URL building and caching
/// logic that was previously inside `_StockCardState` lives here.
class StockChartSection extends StatefulWidget {
  final String symbol;
  final String stockName;

  const StockChartSection({
    super.key,
    required this.symbol,
    required this.stockName,
  });

  @override
  State<StockChartSection> createState() => _StockChartSectionState();
}

class _StockChartSectionState extends State<StockChartSection> {
  static final Map<String, String> _chartCache = {};

  // ─── URL helpers ─────────────────────────────────────────────────────────

  String _getChartUrl(String symbol) {
    final now = DateTime.now();
    // 일봉 차트이므로 같은 날짜 안에서는 캐시를 재사용하고, 날짜가 바뀌면 갱신한다.
    final dateBucket = '${now.year}-${now.month}-${now.day}';
    final cacheKey = '${symbol}_$dateBucket';

    if (_chartCache.containsKey(cacheKey)) {
      return _chartCache[cacheKey]!;
    }

    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;
    final chartUrl =
        'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/day/$symbol.png&t=$secondsSinceEpoch&cache=false';
    _chartCache[cacheKey] = chartUrl;

    if (_chartCache.length > 20) {
      final keysToRemove =
          _chartCache.keys.take(_chartCache.length - 20).toList();
      for (final key in keysToRemove) {
        _chartCache.remove(key);
      }
    }

    return chartUrl;
  }

  String _getDetailedChartUrl(String symbol) {
    final secondsSinceEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/day/$symbol.png&t=$secondsSinceEpoch&w=800&h=600&cache=false';
  }

  String _getDetailedChartUrlWithPeriod(String symbol, String period) {
    final secondsSinceEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String chartType;
    switch (period) {
      case 'year':
        chartType = 'week';
        break;
      case 'three':
        chartType = 'month';
        break;
      default:
        chartType = 'day';
    }
    return 'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/$chartType/$symbol.png&t=$secondsSinceEpoch&w=800&h=600&cache=false';
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'year':
        return '1년 (주봉)';
      case 'three':
        return '3년 (월봉)';
      default:
        return '일봉';
    }
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showDetailedChart() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHigh,
          child: _buildDetailedChartDialog(
            ctx,
            imageUrl: _getDetailedChartUrl(widget.symbol),
            title: '${widget.stockName} (${widget.symbol}) - 상세 차트',
          ),
        );
      },
    );
  }

  void _showDetailedChartWithPeriod(String period) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHigh,
          child: _buildDetailedChartDialog(
            ctx,
            imageUrl: _getDetailedChartUrlWithPeriod(widget.symbol, period),
            title:
                '${widget.stockName} (${widget.symbol}) - ${_getPeriodLabel(period)} 차트',
          ),
        );
      },
    );
  }

  Widget _buildChartPeriodButton(
      BuildContext ctx, String label, String period) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(ctx).pop();
        _showDetailedChartWithPeriod(period);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(ctx).colorScheme.primary,
        foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildDetailedChartDialog(
    BuildContext ctx, {
    required String imageUrl,
    required String title,
  }) {
    final theme = Theme.of(ctx);

    return Container(
      width: MediaQuery.of(ctx).size.width * 0.95,
      height: MediaQuery.of(ctx).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '상세 차트를 불러오는 중...',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 48),
                        const SizedBox(height: 16),
                        Text(
                          '상세 차트를 불러올 수 없습니다',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChartPeriodButton(ctx, '1년', 'year'),
              _buildChartPeriodButton(ctx, '3년', 'three'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Snapshot card ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _showDetailedChart,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '일봉 차트',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.touch_app,
                          color: theme.colorScheme.onSurfaceVariant, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '클릭하여 상세 차트 보기',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _getChartUrl(widget.symbol),
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '차트 로딩 중...',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 24),
                          const SizedBox(height: 4),
                          Text(
                            '차트를 불러올 수 없습니다',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
