import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import '../widgets/stock_card.dart';
import 'us_stock_detail_page.dart';

class UsStockAiRecommendPage extends StatefulWidget {
  const UsStockAiRecommendPage({super.key});

  @override
  State<UsStockAiRecommendPage> createState() => _UsStockAiRecommendPageState();
}

class _UsStockAiRecommendPageState extends State<UsStockAiRecommendPage> {
  List<StockRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recommendations = await FMPService.fetchRecommendedStocks(limit: 20);
      setState(() {
        _recommendations = recommendations;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '추천 주식을 불러올 수 없습니다: $e';
        _isLoading = false;
      });
    }
  }

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
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖 AI 미국 주식 추천', style: TextStyle(color: Colors.white)),
            if (_lastUpdated != null)
              Text(
                '마지막 업데이트: ${_formatLastUpdated(_lastUpdated!)}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecommendations,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, color: Colors.blue, size: 48),
            const SizedBox(height: 16),
            const Text(
              '추천 주식을 불러오는 중입니다',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadRecommendations,
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final rec = _recommendations[index];
          final stock = rec.stock;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.grey[800],
              elevation: 2,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UsStockDetailPage(stock: stock),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더: 이름, 심볼, AI 점수
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stock.symbol,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // AI 점수 배지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getScoreColor(rec.score).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getScoreColor(rec.score),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'AI ${rec.score.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: _getScoreColor(rec.score),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rec.action,
                                  style: TextStyle(
                                    color: _getActionColor(rec.action),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 가격 정보
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (stock.price != null) ...[
                            Text(
                              '\$${stock.price!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          if (stock.changePercent != null) ...[
                            Row(
                              children: [
                                Icon(
                                  stock.changePercent! >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: stock.changePercent! >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: stock.changePercent! >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 추천 이유
                      if (rec.reasons.isNotEmpty) ...[
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 8),
                        Text(
                          '추천 이유:',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...rec.reasons.map((reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: Colors.green[400],
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Buy':
        return Colors.green;
      case 'Hold':
        return Colors.blue;
      case 'Watch':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

