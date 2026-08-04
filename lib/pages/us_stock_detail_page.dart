import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stock.dart';
import '../models/news.dart';
import '../services/fmp_service.dart';
import '../services/us_stock_news_service.dart';
import '../services/news_service.dart';
import '../services/bookmark_service.dart';
import '../utils/number_format_utils.dart';
import '../widgets/kr_stock_kchart_widget.dart';
import '../widgets/us_stock_chart_widget.dart';

class UsStockDetailPage extends StatefulWidget {
  final Stock stock;
  final bool isKorean;

  const UsStockDetailPage({
    super.key,
    required this.stock,
    this.isKorean = false,
  });

  @override
  State<UsStockDetailPage> createState() => _UsStockDetailPageState();
}

class _UsStockDetailPageState extends State<UsStockDetailPage> {
  Stock? _stockDetail;
  List<News> _newsList = [];
  bool _isLoadingDetail = false;
  bool _isLoadingNews = false;
  bool _isBookmarked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStockDetail();
    _loadStockNews();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final result = await BookmarkService.isBookmarked(widget.stock.symbol);
    if (mounted) setState(() => _isBookmarked = result);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkService.removeBookmark(widget.stock.symbol);
    } else {
      await BookmarkService.addStock(
        widget.stock,
        type: widget.isKorean ? 'kr' : 'us',
      );
    }
    await _checkBookmark();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isBookmarked ? '관심종목에 추가되었습니다' : '관심종목에서 제거되었습니다'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _loadStockDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _error = null;
    });

    try {
      final detail = await FMPService.fetchStockDetail(widget.stock.symbol);
      if (!mounted) return;
      setState(() {
        _stockDetail = detail != null ? Stock.fromJson(detail) : widget.stock;
        _isLoadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stockDetail = widget.stock;
        _error = '시세 데이터를 불러오지 못했습니다 (캐시 표시 중)';
        _isLoadingDetail = false;
      });
    }
  }

  bool get _isKoreanStock {
    return widget.isKorean ||
        RegExp(r'^\d+$').hasMatch(widget.stock.symbol) ||
        widget.stock.symbol.endsWith('.KS') ||
        widget.stock.symbol.endsWith('.KQ') ||
        RegExp(r'[가-힣]').hasMatch(widget.stock.name);
  }

  Future<void> _loadStockNews() async {
    setState(() {
      _isLoadingNews = true;
    });

    try {
      final List<News> news;
      if (_isKoreanStock) {
        news = await NewsService.searchStockNews(
          widget.stock.name,
          isKoreanStock: true,
          symbol: widget.stock.symbol,
        );
      } else {
        news = await UsStockNewsService.fetchStockNews(widget.stock.symbol,
            stockName: widget.stock.name);
      }
      if (!mounted) return;
      setState(() {
        _newsList = news;
        _isLoadingNews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingNews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${widget.stock.name} (${widget.stock.symbol})',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.star : Icons.star_border,
              color: _isBookmarked ? Colors.amber : theme.colorScheme.onSurface,
            ),
            onPressed: _toggleBookmark,
            tooltip: _isBookmarked ? '관심종목 제거' : '관심종목 추가',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: () {
              _loadStockDetail();
              _loadStockNews();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12))),
                ]),
              ),
            // 주식 기본 정보
            _buildStockInfoCard(),
            const SizedBox(height: 16),

            // 차트 섹션
            _isKoreanStock
                ? KrStockKChartWidget(symbol: widget.stock.symbol)
                : UsStockChartWidget(symbol: widget.stock.symbol),
            const SizedBox(height: 16),

            // 뉴스 섹션
            _buildNewsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfoCard() {
    final theme = Theme.of(context);
    final stock = _stockDetail ?? widget.stock;
    final price = stock.price ?? 0.0;
    final change = stock.change ?? 0.0;
    final changePercent = stock.changePercent ?? 0.0;
    final isPositive = change >= 0;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        stock.symbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingDetail)
                  CircularProgressIndicator(color: theme.colorScheme.primary)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatPrice(price, stock),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${change >= 0 ? '+' : ''}${_formatChange(change, stock)} (${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 추가 정보
            if (stock.volume != null || stock.marketCap != null) ...[
              Divider(color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (stock.volume != null) ...[
                    Expanded(
                      child: _buildInfoItem(
                        '거래량',
                        _formatNumber(stock.volume!.toDouble()),
                      ),
                    ),
                  ],
                  if (stock.marketCap != null) ...[
                    Expanded(
                      child: _buildInfoItem(
                        '시가총액',
                        '\$${_formatNumber(stock.marketCap!.toDouble())}',
                      ),
                    ),
                  ],
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error,
                        color: theme.colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price, Stock stock) {
    final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol) ||
        stock.symbol.endsWith('.KS') ||
        stock.symbol.endsWith('.KQ') ||
        RegExp(r'[가-힣]').hasMatch(stock.name);

    if (isKorean) {
      return '₩${formatWithCommas(price)}';
    } else {
      return '\$${formatWithCommas(price, decimals: 2)}';
    }
  }

  String _formatChange(double change, Stock stock) {
    final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol) ||
        stock.symbol.endsWith('.KS') ||
        stock.symbol.endsWith('.KQ') ||
        RegExp(r'[가-힣]').hasMatch(stock.name);

    if (isKorean) {
      return '₩${formatWithCommas(change)}';
    } else {
      return '\$${formatWithCommas(change, decimals: 2)}';
    }
  }

  Widget _buildInfoItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildNewsSection() {
    final theme = Theme.of(context);
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
                Text(
                  '관련 뉴스',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_isLoadingNews)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  IconButton(
                    icon:
                        Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                    onPressed: _loadStockNews,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 뉴스 감정 분석 요약 — 로딩 완료 후 항상 표시
            Builder(builder: (ctx) {
              debugPrint(
                  '🧩 감정블럭 조건: isLoading=$_isLoadingNews newsCount=${_newsList.length}');
              if (!_isLoadingNews) return _buildSentimentSummary();
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 12),

            if (_isLoadingNews)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_newsList.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '뉴스를 불러올 수 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...(_newsList.map((news) => _buildNewsItem(news)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(News news) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _launchUrl(news.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (news.sentiment != 'Neutral')
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (news.sentiment == 'Positive'
                              ? Colors.green
                              : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: (news.sentiment == 'Positive'
                              ? Colors.green
                              : Colors.red),
                          width: 1),
                    ),
                    child: Text(
                      news.sentiment == 'Positive' ? '호재' : '악재',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: news.sentiment == 'Positive'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    news.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  news.source,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (news.publishedAt != null && news.publishedAt!.isNotEmpty)
                  Text(
                    _formatDate(news.publishedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 열 수 없습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildSentimentSummary() {
    debugPrint(
        '🔍 _buildSentimentSummary 호출됨: 뉴스 ${_newsList.length}개, isLoading=$_isLoadingNews');
    int score = 0;
    int positiveCount = 0;
    int negativeCount = 0;

    for (var news in _newsList) {
      if (news.sentiment == 'Positive') {
        score++;
        positiveCount++;
      } else if (news.sentiment == 'Negative') {
        score--;
        negativeCount++;
      }
    }

    if (_newsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined,
                color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Text(
              '뉴스 감정 분석 동향',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text('데이터 없음',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    String signal;
    Color signalColor;
    IconData signalIcon;

    if (score >= 3) {
      signal = '긍정적 흐름 (Positive)';
      signalColor = Colors.green[700]!;
      signalIcon = Icons.trending_up;
    } else if (score >= 1) {
      signal = '다소 긍정적';
      signalColor = Colors.green;
      signalIcon = Icons.sentiment_satisfied;
    } else if (score <= -3) {
      signal = '부정적 흐름 (Negative)';
      signalColor = Colors.red[700]!;
      signalIcon = Icons.trending_down;
    } else if (score <= -1) {
      signal = '다소 부정적';
      signalColor = Colors.red;
      signalIcon = Icons.sentiment_dissatisfied;
    } else {
      signal = '중립 / 관망 (Neutral)';
      signalColor = Colors.grey;
      signalIcon = Icons.remove_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: signalColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: signalColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(signalIcon, color: signalColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '뉴스 감정 분석 동향',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Text(
                signal,
                style: TextStyle(
                  color: signalColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (positiveCount > 0)
                Expanded(
                  flex: positiveCount,
                  child: Container(height: 4, color: Colors.green),
                ),
              if (negativeCount > 0)
                Expanded(
                  flex: negativeCount,
                  child: Container(height: 4, color: Colors.red),
                ),
              if (positiveCount == 0 && negativeCount == 0)
                Expanded(child: Container(height: 4, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('호재성 $positiveCount건',
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
              Text('악재성 $negativeCount건',
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          )
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1e9) {
      return '${(number / 1e9).toStringAsFixed(1)}B';
    } else if (number >= 1e6) {
      return '${(number / 1e6).toStringAsFixed(1)}M';
    } else if (number >= 1e3) {
      return '${(number / 1e3).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      return dateString;
    }
  }
}
