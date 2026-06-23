import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

/// Displays the AppBar title area: the page title and optional last-updated
/// timestamp.  Rendered as a Column so it can be embedded directly in
/// [AppBar.title].
class AiRecommendHeader extends StatelessWidget {
  final DateTime? lastUpdated;

  const AiRecommendHeader({super.key, this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🤖 AI 종목 추천',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (lastUpdated != null)
          Text(
            '마지막 업데이트: ${formatTimeAgo(lastUpdated!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}
