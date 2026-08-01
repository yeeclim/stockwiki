import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

/// 매물대(Volume Profile) 근사 위젯.
///
/// KIS Open API는 과거 분봉/틱 데이터를 제공하지 않아 정확한 체결 매물대를 만들 수
/// 없다. 대신 일봉의 고가~저가 구간에 그날 거래량을 균등 분산시켜 누적하는 방식으로
/// 근사한다 — 실제 체결가 분포보다는 덜 정밀하지만 지지/저항 구간을 참고하기엔 충분하다.
class KrVolumeProfileWidget extends StatelessWidget {
  final List<KLineEntity> candles;
  final int lookbackDays;
  final int binCount;

  const KrVolumeProfileWidget({
    super.key,
    required this.candles,
    this.lookbackDays = 120,
    this.binCount = 24,
  });

  List<_VolumeBin> _computeBins() {
    if (candles.isEmpty) return [];
    final window = candles.length > lookbackDays
        ? candles.sublist(candles.length - lookbackDays)
        : candles;

    double minLow = window.first.low;
    double maxHigh = window.first.high;
    for (final c in window) {
      if (c.low < minLow) minLow = c.low;
      if (c.high > maxHigh) maxHigh = c.high;
    }
    if (maxHigh <= minLow) return [];

    final binSize = (maxHigh - minLow) / binCount;
    final volumes = List<double>.filled(binCount, 0);

    for (final c in window) {
      final low = c.low;
      final high = c.high;
      final range = high - low;
      if (range <= 0) {
        final idx = (((low - minLow) / binSize).floor()).clamp(0, binCount - 1);
        volumes[idx] += c.vol;
        continue;
      }
      // 해당 일봉의 저가~고가 구간과 겹치는 각 빈에 거래량을 겹치는 길이 비율만큼 분산
      final startIdx =
          (((low - minLow) / binSize).floor()).clamp(0, binCount - 1);
      final endIdx =
          (((high - minLow) / binSize).floor()).clamp(0, binCount - 1);
      for (int i = startIdx; i <= endIdx; i++) {
        final binLow = minLow + i * binSize;
        final binHigh = binLow + binSize;
        final overlap = _overlapLength(low, high, binLow, binHigh);
        if (overlap > 0) {
          volumes[i] += c.vol * (overlap / range);
        }
      }
    }

    return List.generate(binCount, (i) {
      final priceLow = minLow + i * binSize;
      return _VolumeBin(
        priceLow: priceLow,
        priceHigh: priceLow + binSize,
        priceMid: priceLow + binSize / 2,
        volume: volumes[i],
      );
    });
  }

  double _overlapLength(double aLow, double aHigh, double bLow, double bHigh) {
    final low = aLow > bLow ? aLow : bLow;
    final high = aHigh < bHigh ? aHigh : bHigh;
    return high > low ? high - low : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bins = _computeBins();
    if (bins.isEmpty) return const SizedBox.shrink();

    final maxVolume = bins.map((b) => b.volume).reduce((a, b) => a > b ? a : b);
    final currentPrice = candles.last.close;
    // 가장 거래량이 몰린 구간(POC, Point of Control)
    final pocBin = bins.reduce((a, b) => a.volume > b.volume ? a : b);

    return Card(
      elevation: theme.cardTheme.elevation,
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('매물대 (최근 $lookbackDays거래일, 근사치)',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('최다거래가 ${pocBin.priceMid.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            ...bins.reversed.map((bin) {
              final ratio = maxVolume > 0 ? bin.volume / maxVolume : 0.0;
              final containsCurrent =
                  currentPrice >= bin.priceLow && currentPrice < bin.priceHigh;
              final isPoc = bin == pocBin;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 62,
                      child: Text(
                        bin.priceMid.toStringAsFixed(0),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: containsCurrent
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isPoc || containsCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio.clamp(0.02, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: isPoc
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary
                                    .withValues(alpha: 0.35),
                            border: containsCurrent
                                ? Border.all(
                                    color: theme.colorScheme.secondary,
                                    width: 1.5)
                                : null,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _VolumeBin {
  final double priceLow;
  final double priceHigh;
  final double priceMid;
  final double volume;
  const _VolumeBin({
    required this.priceLow,
    required this.priceHigh,
    required this.priceMid,
    required this.volume,
  });
}
