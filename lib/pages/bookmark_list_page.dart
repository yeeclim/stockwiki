import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';
import '../models/stock.dart';
import 'us_stock_detail_page.dart';

class BookmarkListPage extends StatefulWidget {
  const BookmarkListPage({super.key});

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final bookmarks = await BookmarkService.getAllBookmarkDetails();
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(String stockCode, String stockName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관심종목 제거'),
        content: Text('$stockName을(를) 관심종목에서 제거하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('제거', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BookmarkService.removeBookmark(stockCode);
      await _loadBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$stockName이(가) 관심종목에서 제거되었습니다.'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> bookmark) {
    final type = bookmark['type'] as String? ?? 'us';
    final stock = Stock(
      symbol: bookmark['symbol'] as String? ?? bookmark['stockCode'] as String? ?? '',
      name: bookmark['stockName'] as String? ?? '',
      price: (bookmark['price'] as num?)?.toDouble(),
      changePercent: (bookmark['changePercent'] as num?)?.toDouble(),
      change: (bookmark['change'] as num?)?.toDouble(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UsStockDetailPage(stock: stock, isKorean: type == 'kr')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('관심종목'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 72, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('관심종목이 없습니다', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              '종목 상세 페이지에서 ★ 버튼으로 추가하세요',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) => _buildCard(_bookmarks[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> bookmark) {
    final theme = Theme.of(context);
    final stockName = bookmark['stockName'] as String? ?? 'N/A';
    final stockCode = bookmark['symbol'] as String? ?? bookmark['stockCode'] as String? ?? '';
    final type = bookmark['type'] as String? ?? 'us';
    final isKorean = type == 'kr';
    final price = (bookmark['price'] as num?)?.toDouble();
    final changePercent = (bookmark['changePercent'] as num?)?.toDouble();
    final isPositive = (changePercent ?? 0) >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: theme.cardTheme.elevation,
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: InkWell(
        onTap: () => _navigateToDetail(bookmark),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 국기 + 종목 정보
              Expanded(
                child: Row(
                  children: [
                    Text(isKorean ? '🇰🇷' : '🇺🇸', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stockName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stockCode,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 가격 + 등락률
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (price != null)
                    Text(
                      isKorean ? '₩${price.toInt().toLocaleString()}' : '\$${price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  if (changePercent != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              // 제거 버튼
              IconButton(
                icon: Icon(Icons.star, color: Colors.amber.shade600, size: 22),
                onPressed: () => _removeBookmark(stockCode, stockName),
                tooltip: '관심종목 제거',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on int {
  String toLocaleString() {
    final s = toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
