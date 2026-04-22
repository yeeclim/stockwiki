import 'package:flutter/material.dart';

/// Displays the AppBar title area: the page title and optional last-updated
/// timestamp.  Rendered as a Column so it can be embedded directly in
/// [AppBar.title].
class AiRecommendHeader extends StatelessWidget {
  final DateTime? lastUpdated;

  const AiRecommendHeader({super.key, this.lastUpdated});

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
      return '${dateTime.month}/${dateTime.day} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

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
            '마지막 업데이트: ${_formatLastUpdated(lastUpdated!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}
