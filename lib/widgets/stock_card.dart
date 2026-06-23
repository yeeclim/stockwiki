import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/news.dart';
import '../services/news_service.dart';
import 'stock_price_badge.dart';
import 'stock_chart_section.dart';
import 'stock_news_section.dart';

class StockCard extends StatefulWidget {
  final Stock stock;
  const StockCard({super.key, required this.stock});

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  List<News> _newsList = [];
  bool _isLoadingNews = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    if (widget.stock.name.isEmpty) return;

    setState(() {
      _isLoadingNews = true;
    });

    try {
      final news = await NewsService.searchStockNews(
        widget.stock.name,
        isKoreanStock: true,
      );
      if (!mounted) return;
      setState(() {
        _newsList = news;
        _isLoadingNews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingNews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRealTimeData =
        widget.stock.price != null && widget.stock.price! > 0;
    final hasChartData = widget.stock.symbol.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: symbol/name on the left, price on the right ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stock.symbol,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stock.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Right-hand price column
                if (hasRealTimeData)
                  StockPriceBadge(price: widget.stock.price)
                      .buildPriceColumn(context),
              ],
            ),

            // ── Secondary row: volume / market-cap / update time ──────────
            if (hasRealTimeData)
              StockPriceBadge(
                price: widget.stock.price,
                volume: widget.stock.volume,
                marketCap: widget.stock.marketCap,
                lastUpdate: widget.stock.lastUpdate,
              ).buildSecondaryRow(context),

            // ── Chart snapshot ────────────────────────────────────────────
            if (hasChartData) ...[
              const SizedBox(height: 16),
              StockChartSection(
                symbol: widget.stock.symbol,
                stockName: widget.stock.name,
              ),
              const SizedBox(height: 16),
            ],

            // ── News section ─────────────────────────────────────────────
            const SizedBox(height: 16),
            StockNewsSection(
              newsList: _newsList,
              isLoading: _isLoadingNews,
            ),
          ],
        ),
      ),
    );
  }
}
