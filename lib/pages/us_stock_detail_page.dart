import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stock.dart';
import '../models/news.dart';
import '../services/fmp_service.dart';
import '../services/us_stock_news_service.dart';
import '../widgets/us_stock_chart_widget.dart';

class UsStockDetailPage extends StatefulWidget {
  final Stock stock;

  const UsStockDetailPage({
    super.key,
    required this.stock,
  });

  @override
  State<UsStockDetailPage> createState() => _UsStockDetailPageState();
}

class _UsStockDetailPageState extends State<UsStockDetailPage> {
  Stock? _stockDetail;
  List<News> _newsList = [];
  bool _isLoadingDetail = false;
  bool _isLoadingNews = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStockDetail();
    _loadStockNews();
  }

  Future<void> _loadStockDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _error = null;
    });

    try {
      final detail = await FMPService.fetchStockDetail(widget.stock.symbol);
      if (detail != null) {
        setState(() {
          _stockDetail = Stock.fromJson(detail);
          _isLoadingDetail = false;
        });
      } else {
        setState(() {
          _error = '주식 상세 정보를 불러올 수 없습니다';
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '오류 발생: $e';
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _loadStockNews() async {
    setState(() {
      _isLoadingNews = true;
    });

    try {
      final news = await UsStockNewsService.fetchStockNews(widget.stock.symbol);
      setState(() {
        _newsList = news;
        _isLoadingNews = false;
      });
    } catch (e) {
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
            // 주식 기본 정보
            _buildStockInfoCard(),
            const SizedBox(height: 16),
            
            // 차트 섹션
            UsStockChartWidget(symbol: widget.stock.symbol),
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
                        '\$${price.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up : Icons.trending_down,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%)',
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
                    Icon(Icons.error, color: theme.colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
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
                    icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                    onPressed: _loadStockNews,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 뉴스 감정 분석 요약 (매매 신호)
            if (!_isLoadingNews && _newsList.isNotEmpty)
              _buildSentimentSummary(),

            const SizedBox(height: 12),
            
            if (_newsList.isEmpty && !_isLoadingNews)
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (news.sentiment == 'Positive' ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: (news.sentiment == 'Positive' ? Colors.green : Colors.red), width: 1),
                    ),
                    child: Text(
                      news.sentiment == 'Positive' ? '호재' : '악재',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: news.sentiment == 'Positive' ? Colors.green : Colors.red,
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

    String signal;
    Color signalColor;
    IconData signalIcon;

    if (score >= 3) {
      signal = '강력 매수';
      signalColor = Colors.green[700]!;
      signalIcon = Icons.sentiment_very_satisfied;
    } else if (score >= 1) {
      signal = '매수';
      signalColor = Colors.green;
      signalIcon = Icons.sentiment_satisfied;
    } else if (score <= -3) {
      signal = '강력 매도';
      signalColor = Colors.red[700]!;
      signalIcon = Icons.sentiment_very_dissatisfied;
    } else if (score <= -1) {
      signal = '매도';
      signalColor = Colors.red;
      signalIcon = Icons.sentiment_dissatisfied;
    } else {
      signal = '관망 (중립)';
      signalColor = Colors.grey;
      signalIcon = Icons.sentiment_neutral;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: signalColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: signalColor, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: signalColor,
            radius: 24,
            child: Icon(signalIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '뉴스 기반 매매 의견',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  signal,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: signalColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '호재 $positiveCount',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              Text(
                '악재 $negativeCount',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
