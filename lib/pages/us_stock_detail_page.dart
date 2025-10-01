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
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          '${widget.stock.name} (${widget.stock.symbol})',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
            
            // 차트
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
    final stock = _stockDetail ?? widget.stock;
    final price = stock.price ?? 0.0;
    final change = stock.change ?? 0.0;
    final changePercent = stock.changePercent ?? 0.0;
    final isPositive = change >= 0;

    return Card(
      color: Colors.grey[800],
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.symbol,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingDetail)
                  const CircularProgressIndicator()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontSize: 16,
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
              const Divider(color: Colors.grey),
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
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNewsSection() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '관련 뉴스',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoadingNews)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadStockNews,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_newsList.isEmpty && !_isLoadingNews)
              Container(
                padding: const EdgeInsets.all(20),
                child: const Center(
                  child: Text(
                    '뉴스를 불러올 수 없습니다',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _launchUrl(news.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              news.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (news.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                news.description,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  news.source,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
                if (news.publishedAt != null && news.publishedAt!.isNotEmpty)
                  Text(
                    _formatDate(news.publishedAt!),
                    style: TextStyle(
                      color: Colors.grey[400],
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
