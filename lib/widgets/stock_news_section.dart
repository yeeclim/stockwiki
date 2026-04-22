import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news.dart';

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
    try {
      final dateTime = DateTime.parse(publishedAt);
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
        return '${dateTime.month}/${dateTime.day}';
      }
    } catch (_) {
      return '알 수 없음';
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // URL 실행 오류 — 무시
    }
  }

  // ─── News item ────────────────────────────────────────────────────────────

  Widget _buildNewsItem(News news) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[600]!, width: 0.5),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.open_in_new, color: Colors.grey[400], size: 16),
              ],
            ),
            if (news.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                news.description,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
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
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
                if (news.publishedAt != null)
                  Text(
                    formatNewsTime(news.publishedAt!),
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 10),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
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
                const Text(
                  '관련 뉴스',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                else
                  Text(
                    '${newsList.length}개',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                  ),
              ],
            ),
          ),

          // Body
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '뉴스를 불러오는 중...',
                  style:
                      TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            )
          else if (newsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '관련 뉴스가 없습니다',
                  style:
                      TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            )
          else
            ...newsList.map(_buildNewsItem),
        ],
      ),
    );
  }
}
