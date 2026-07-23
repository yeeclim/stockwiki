import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// BTC·WTI·Gold·Silver·USD/KRW 위젯의 공통 행(row) 구조.
/// 증권 터미널 스타일 — 고정폭 숫자, 상승/하락 빨강·파랑 고정.
/// 데이터 페칭/캐싱 로직은 각 위젯 State에 남기고, 이 위젯은 UI 렌더링만 담당한다.
/// 실제 테두리·구분선·hover 효과는 이 위젯을 감싸는 [TerminalGrid]가 담당하므로
/// 여기서는 카드/보더 없이 한 줄 콘텐츠만 그린다.
class MarketDataCard extends StatelessWidget {
  final Color accentColor;
  final Widget headerIcon;
  final String title;
  final bool isLoading;
  final String? error;
  final String? valueText;
  final String? subText;

  /// 전일 대비 변동률(%). 양수=상승(빨강) / 음수=하락(파랑). null이면 표시 안 함.
  final double? changePercent;

  const MarketDataCard({
    super.key,
    required this.accentColor,
    required this.headerIcon,
    required this.title,
    required this.isLoading,
    this.error,
    this.valueText,
    this.subText,
    this.changePercent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final market = theme.extension<MarketColors>()!;
    const numberFont = 'monospace';

    if (isLoading) {
      return Row(
        children: [
          _badge(market),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: market.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          Text('…',
              style: TextStyle(color: market.muted, fontFamily: numberFont)),
        ],
      );
    }

    if (error != null) {
      return Row(
        children: [
          _badge(market),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: market.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          Text(error!, style: TextStyle(color: market.muted, fontSize: 11.5)),
        ],
      );
    }

    final change = changePercent;
    final isUp = (change ?? 0) >= 0;
    final changeColor =
        change == null ? market.muted : (isUp ? market.up : market.down);

    return Row(
      children: [
        _badge(market),
        const SizedBox(width: 10),
        Expanded(
          flex: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: market.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              if (subText != null)
                Text(subText!,
                    style: TextStyle(color: market.muted, fontSize: 10.5)),
            ],
          ),
        ),
        Expanded(
          flex: 9,
          child: Text(
            valueText ?? 'N/A',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: market.ink,
              fontFamily: numberFont,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 12.5,
            ),
          ),
        ),
        if (change != null)
          Expanded(
            flex: 8,
            child: Text(
              '${isUp ? '▲' : '▼'}${change.abs().toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: changeColor,
                fontFamily: numberFont,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(MarketColors market) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: headerIcon,
    );
  }
}
