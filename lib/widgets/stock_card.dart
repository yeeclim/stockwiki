import 'package:flutter/material.dart';
import '../models/stock.dart';

class StockCard extends StatelessWidget {
  final Stock stock;
  static final Map<String, String> _chartCache = {};

  const StockCard({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    // 실시간 데이터가 있는지 확인 (차트는 항상 표시)
    final hasRealTimeData = stock.price != null && stock.price! > 0;
    final hasChartData = stock.symbol.isNotEmpty; // 종목코드가 있으면 차트 표시
    final change = stock.change ?? 0.0;
    final changePercent = stock.changePercent ?? 0.0;
    final isPositive = change >= 0;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        stock.symbol,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stock.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasRealTimeData) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₩${stock.price!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '전일 종가',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (hasRealTimeData) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (stock.volume != null)
                    Text(
                      '거래량: ${_formatVolume(stock.volume!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (stock.marketCap != null && stock.marketCap! > 0)
                    Text(
                      '시가총액: ${_formatMarketCap(stock.marketCap!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              if (stock.lastUpdate != null)
                const SizedBox(height: 4),
              if (stock.lastUpdate != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '업데이트: ${_formatTime(stock.lastUpdate!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
            // 차트 스냅샷 추가 (종목코드가 있으면 항상 표시)
            if (hasChartData) ...[
              const SizedBox(height: 16),
              _buildChartSnapshot(),
            ],
          ],
        ),
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }

  String _formatMarketCap(int marketCap) {
    if (marketCap >= 1000000000000) { // 1조 이상
      return '${(marketCap / 1000000000000).toStringAsFixed(1)}조';
    } else if (marketCap >= 100000000) { // 1억 이상
      return '${(marketCap / 100000000).toStringAsFixed(1)}억';
    } else if (marketCap >= 10000) { // 1만 이상
      return '${(marketCap / 10000).toStringAsFixed(1)}만';
    }
    return marketCap.toString();
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${dateTime.month}/${dateTime.day}';
      }
    } catch (e) {
      return '알 수 없음';
    }
  }

  Widget _buildChartSnapshot() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '일봉 차트',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '실시간',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[600]!, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _getChartUrl(stock.symbol),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '차트 로딩 중...',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '차트를 불러올 수 없습니다',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getChartUrl(String symbol) {
    // 5분마다 새로운 차트를 가져오도록 타임스탬프 추가
    final now = DateTime.now();
    final minutesSinceEpoch = now.millisecondsSinceEpoch ~/ (5 * 60 * 1000); // 5분 단위
    
    final cacheKey = '${symbol}_$minutesSinceEpoch';
    
    if (_chartCache.containsKey(cacheKey)) {
      return _chartCache[cacheKey]!;
    }
    
    final chartUrl = 'https://ssl.pstatic.net/imgfinance/chart/item/candle/day/$symbol.png?t=$minutesSinceEpoch';
    _chartCache[cacheKey] = chartUrl;
    
    // 캐시 크기 제한 (최대 50개)
    if (_chartCache.length > 50) {
      final keysToRemove = _chartCache.keys.take(_chartCache.length - 50).toList();
      for (final key in keysToRemove) {
        _chartCache.remove(key);
      }
    }
    
    return chartUrl;
  }
}
