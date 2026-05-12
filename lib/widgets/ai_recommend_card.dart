import 'package:flutter/material.dart';
import '../pages/ai_stock_recommend_page.dart';

/// A self-contained card that renders a single [StockRecommendation].
///
/// All display logic that was previously in
/// `_AiStockRecommendPageState._buildRecommendationCard` (and its helpers) has
/// been moved here so the main page can stay thin.
class AiRecommendCard extends StatelessWidget {
  final StockRecommendation rec;
  final VoidCallback? onChartTap;

  const AiRecommendCard({super.key, required this.rec, this.onChartTap});

  // ─── Formatters ──────────────────────────────────────────────────────────

  static String formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }

  // ─── Action badge ─────────────────────────────────────────────────────────

  Widget _buildActionBadge(BuildContext context) {
    final theme = Theme.of(context);
    Color bgColor;
    Color textColor;

    switch (rec.action) {
      case '매수':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case '매도':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        rec.action,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Target prices ────────────────────────────────────────────────────────

  Widget _buildTargetPrices(BuildContext context) {
    final theme = Theme.of(context);

    if (rec.currentPrice <= 0) return const SizedBox.shrink();

    int basePrice;
    String priceLabel;

    if (rec.currentPrice > 0 && rec.priceSource == 'real-time') {
      basePrice = rec.currentPrice;
      priceLabel = '현재가 기준';
    } else if (rec.previousClose != null && rec.previousClose! > 0) {
      basePrice = rec.previousClose!;
      priceLabel = '전일 종가 기준';
    } else {
      return const SizedBox.shrink();
    }

    final dayTarget = (basePrice * 1.03).round();
    final swingTarget = (basePrice * 1.08).round();
    final longTarget = (basePrice * 1.20).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '🎯 기간별 목표가',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (priceLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priceLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTargetPriceCard(
                context,
                title: '단타',
                period: '1~3일',
                targetPrice: dayTarget,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTargetPriceCard(
                context,
                title: '스윙',
                period: '1주~1개월',
                targetPrice: swingTarget,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTargetPriceCard(
                context,
                title: '중장기',
                period: '3개월~1년',
                targetPrice: longTarget,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetPriceCard(
    BuildContext context, {
    required String title,
    required String period,
    required int targetPrice,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            period,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₩${formatPrice(targetPrice)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Trading strategies ───────────────────────────────────────────────────

  Widget _buildTradingStrategies(BuildContext context, int basePrice) {
    final theme = Theme.of(context);
    if (basePrice <= 0) return const SizedBox.shrink();

    final strategies = [
      _buildStrategyCard(
        context,
        title: '🎯 단타',
        subtitle: '1~3일',
        currentPrice: basePrice,
        buyPricePercent: 99.5,
        sellPricePercent: 103.0,
        stopLossPercent: 98.0,
        expectedReturn: 3.0,
        color: Colors.orange,
      ),
      _buildStrategyCard(
        context,
        title: '📊 스윙',
        subtitle: '1주~1개월',
        currentPrice: basePrice,
        buyPricePercent: 98.5,
        sellPricePercent: 108.0,
        stopLossPercent: 96.0,
        expectedReturn: 8.5,
        color: Colors.blue,
      ),
      _buildStrategyCard(
        context,
        title: '📈 중장기',
        subtitle: '3개월~1년',
        currentPrice: basePrice,
        buyPricePercent: 100.0,
        sellPricePercent: 120.0,
        stopLossPercent: 93.0,
        expectedReturn: 20.0,
        color: Colors.green,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💼 투자 전략',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: strategies
                .map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: s,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int currentPrice,
    required double buyPricePercent,
    required double sellPricePercent,
    required double stopLossPercent,
    required double expectedReturn,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final buyPrice = (currentPrice * buyPricePercent / 100).round();
    final sellPrice = (currentPrice * sellPricePercent / 100).round();
    final stopLoss = (currentPrice * stopLossPercent / 100).round();

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${expectedReturn.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          _priceRow(context, '매수', '₩${formatPrice(buyPrice)}',
              theme.colorScheme.onSurface),
          const SizedBox(height: 4),
          _priceRow(context, '매도', '₩${formatPrice(sellPrice)}', color),
          const SizedBox(height: 4),
          _priceRow(context, '손절', '₩${formatPrice(stopLoss)}', Colors.red),
        ],
      ),
    );
  }

  Widget _priceRow(
      BuildContext context, String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── Main build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: theme.cardTheme.elevation,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header: AI avatar + time + action badge ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.auto_graph,
                      color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StockWiki AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        formatTimeAgo(rec.postedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionBadge(context),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // ── Stock info body ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock name + code
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            rec.stockName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rec.stockCode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Target prices
                _buildTargetPrices(context),
                const SizedBox(height: 16),

                // Reasons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 16,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '추천 근거',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...rec.reasons.map((reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      height: 1.4,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                // Trading strategies (only when price is available)
                if (rec.currentPrice > 0) ...[
                  const SizedBox(height: 12),
                  _buildTradingStrategies(context, rec.currentPrice),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onChartTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.bar_chart, size: 13, color: theme.colorScheme.primary),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
