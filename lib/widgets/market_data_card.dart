import 'package:flutter/material.dart';

/// BTC·WTI·Gold·Silver·USD/KRW·Fear&Greed 위젯의 공통 Card 구조.
///
/// 데이터 페칭/캐싱 로직은 각 위젯 State에 남기고,
/// 이 위젯은 UI 렌더링만 담당합니다.
class MarketDataCard extends StatelessWidget {
  final Color accentColor;

  /// 헤더 원형 배경 안의 아이콘 (Icon 또는 Text 위젯)
  final Widget headerIcon;
  final String title;
  final bool isLoading;
  final String? error;

  /// 주요 값 텍스트 (null 이면 로딩/에러 상태로 간주)
  final String? valueText;

  /// 보조 설명 (단위, 환산가 등)
  final String? subText;

  const MarketDataCard({
    super.key,
    required this.accentColor,
    required this.headerIcon,
    required this.title,
    required this.isLoading,
    this.error,
    this.valueText,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientOpacity = isDark ? 0.15 : 0.10;

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: gradientOpacity),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── 헤더 (아이콘 + 제목) ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: headerIcon,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            // ── 값 영역 ─────────────────────────────────────────────────
            if (isLoading)
              Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: accentColor),
                ),
              )
            else if (error != null)
              Center(
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    valueText ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  if (subText != null)
                    Text(
                      subText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
