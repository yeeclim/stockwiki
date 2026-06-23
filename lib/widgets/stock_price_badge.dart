import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

/// Renders the price column (current price + "전일 종가" label) shown on the
/// right side of the stock card header row, and the secondary row containing
/// volume, market-cap and last-update timestamp.
///
/// Pass [price], [volume], [marketCap], [lastUpdate] directly from the [Stock]
/// model.  When [price] is null or zero, nothing is rendered (the widget
/// returns an empty [SizedBox]).
class StockPriceBadge extends StatelessWidget {
  final double? price;
  final int? volume;
  final int? marketCap;
  final String? lastUpdate;

  const StockPriceBadge({
    super.key,
    this.price,
    this.volume,
    this.marketCap,
    this.lastUpdate,
  });

  bool get _hasRealTimeData => price != null && price! > 0;

  // ─── Formatters ──────────────────────────────────────────────────────────

  static String formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }

  static String formatMarketCap(int marketCap) {
    if (marketCap >= 1000000000000) {
      return '${(marketCap / 1000000000000).toStringAsFixed(1)}조';
    } else if (marketCap >= 100000000) {
      return '${(marketCap / 100000000).toStringAsFixed(1)}억';
    } else if (marketCap >= 10000) {
      return '${(marketCap / 10000).toStringAsFixed(1)}만';
    }
    return marketCap.toString();
  }

  static String formatTime(String isoString) {
    return formatTimeAgoFromString(isoString);
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  /// Right-hand price column used inside the card header [Row].
  Widget buildPriceColumn(BuildContext context) {
    if (!_hasRealTimeData) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '₩${price!.toStringAsFixed(0)}',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '전일 종가',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Secondary row with volume, market-cap and timestamp.
  Widget buildSecondaryRow(BuildContext context) {
    if (!_hasRealTimeData) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (volume != null)
              Text(
                '거래량: ${formatVolume(volume!)}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            if (marketCap != null && marketCap! > 0)
              Text(
                '시가총액: ${formatMarketCap(marketCap!)}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
          ],
        ),
        if (lastUpdate != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '업데이트: ${formatTime(lastUpdate!)}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Convenience full build: renders nothing when there is no price data.
  @override
  Widget build(BuildContext context) {
    if (!_hasRealTimeData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSecondaryRow(context),
      ],
    );
  }
}
