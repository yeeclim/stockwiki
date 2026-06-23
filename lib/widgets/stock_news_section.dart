import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news.dart';
import '../utils/date_utils.dart';

/// Renders the "관련 뉴스" container that was previously embedded in
/// `_StockCardState._buildNewsSection` / `_buildNewsItem`.
///
/// Accepts the already-fetched [newsList] and a [isLoading] flag so the
/// parent card can control data fetching independently.
class StockNewsSection extends StatelessWidget {
  final List<News> newsList;
  final bool isLoading;

  const StockNewsSection({
    super.key,
    required this.newsList,
    required this.isLoading,
  });

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String formatNewsTime(String publishedAt) {
    return formatTimeAgoFromString(publishedAt);
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ─── News item ────────────────────────────────────────────────────────────

  Widget _buildNewsItem(BuildContext context, News news) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 0.5),
      ),
      child: InkWell(
        onTap: () => _launchUrl(news.link),
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    news.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.open_in_new,
                    color: theme.colorScheme.onSurfaceVariant, size: 16),
              ],
            ),
            if (news.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                news.description,
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  news.source,
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                      fontSize: 10),
                ),
                if (news.publishedAt != null)
                  Text(
                    formatNewsTime(news.publishedAt!),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '관련 뉴스',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                    ),
                  )
                else
                  Text(
                    '${newsList.length}개',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
              ],
            ),
          ),

          // Body
          if (isLoading)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '뉴스를 불러오는 중...',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            )
          else if (newsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '관련 뉴스가 없습니다',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            )
          else
            ...newsList.map((n) => _buildNewsItem(context, n)),
        ],
      ),
    );
  }
}
