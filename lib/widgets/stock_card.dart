import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stock.dart';
import '../models/news.dart';
import '../services/news_service.dart';
import 'chart_analysis_widget.dart';

class StockCard extends StatefulWidget {
  final Stock stock;
  static final Map<String, String> _chartCache = {};

  const StockCard({super.key, required this.stock});

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  List<News> _newsList = [];
  bool _isLoadingNews = false;
  static final Map<String, String> _chartCache = {};

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
      // 국내주식으로 가정 (KRX 데이터에서 온 경우)
      final news = await NewsService.searchStockNews(widget.stock.name, isKoreanStock: true);
      setState(() {
        _newsList = news;
        _isLoadingNews = false;
      });
      print('StockCard 뉴스 로딩 완료: ${news.length}개 (국내주식)');
    } catch (e) {
      setState(() {
        _isLoadingNews = false;
      });
      print('StockCard 뉴스 로딩 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 실시간 데이터가 있는지 확인 (차트는 항상 표시)
    final hasRealTimeData = widget.stock.price != null && widget.stock.price! > 0;
    final hasChartData = widget.stock.symbol.isNotEmpty; // 종목코드가 있으면 차트 표시
    final change = widget.stock.change ?? 0.0;
    final changePercent = widget.stock.changePercent ?? 0.0;
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
                        widget.stock.symbol,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stock.name,
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
                        '₩${widget.stock.price!.toStringAsFixed(0)}',
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
                  if (widget.stock.volume != null)
                    Text(
                      '거래량: ${_formatVolume(widget.stock.volume!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (widget.stock.marketCap != null && widget.stock.marketCap! > 0)
                    Text(
                      '시가총액: ${_formatMarketCap(widget.stock.marketCap!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              if (widget.stock.lastUpdate != null)
                const SizedBox(height: 4),
              if (widget.stock.lastUpdate != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '업데이트: ${_formatTime(widget.stock.lastUpdate!)}',
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
              const SizedBox(height: 16),
              // 차트 분석 위젯 추가
              ChartAnalysisWidget(
                symbol: widget.stock.symbol,
                stockName: widget.stock.name,
                currentPrice: widget.stock.price,
                volume: widget.stock.volume,
              ),
            ],
            // 관련 뉴스 섹션 추가
            const SizedBox(height: 16),
            _buildNewsSection(),
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
    return GestureDetector(
      onTap: () => _showDetailedChart(),
      child: Container(
        width: double.infinity,
        height: 200, // 높이를 150에서 200으로 증가
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
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '클릭하여 상세 차트 보기',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
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
                    _getChartUrl(widget.stock.symbol),
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
      ),
    );
  }

  void _showDetailedChart() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.stock.name} (${widget.stock.symbol}) - 상세 차트',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _getDetailedChartUrl(widget.stock.symbol),
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '상세 차트를 불러오는 중...',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
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
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '상세 차트를 불러올 수 없습니다',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildChartPeriodButton('1년', 'year'),
                    _buildChartPeriodButton('3년', 'three'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartPeriodButton(String label, String period) {
    return ElevatedButton(
      onPressed: () {
        // 현재 다이얼로그 닫고 새로운 기간으로 다시 열기
        Navigator.of(context).pop();
        _showDetailedChartWithPeriod(period);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _showDetailedChartWithPeriod(String period) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.stock.name} (${widget.stock.symbol}) - ${_getPeriodLabel(period)} 차트',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _getDetailedChartUrlWithPeriod(widget.stock.symbol, period),
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '차트를 불러오는 중...',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
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
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '차트를 불러올 수 없습니다',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildChartPeriodButton('1년', 'year'),
                    _buildChartPeriodButton('3년', 'three'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'year': return '1년 (주봉)';
      case 'three': return '3년 (월봉)';
      default: return '일봉';
    }
  }

  String _getChartUrl(String symbol) {
    // 매번 새로운 차트를 가져오도록 타임스탬프를 더 자주 변경
    final now = DateTime.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000; // 1초 단위로 변경
    
    final cacheKey = '${symbol}_$secondsSinceEpoch';
    
    if (_chartCache.containsKey(cacheKey)) {
      return _chartCache[cacheKey]!;
    }
    
    // 직접 네이버 URL 사용 (CORS 우회를 위해 프록시 서비스 사용)
    // 캐시 무효화를 위해 더 자주 변경되는 타임스탬프 사용
    final chartUrl = 'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/day/$symbol.png&t=$secondsSinceEpoch&cache=false';
    _chartCache[cacheKey] = chartUrl;
    
    // 캐시 크기 제한 (최대 20개로 줄임)
    if (_chartCache.length > 20) {
      final keysToRemove = _chartCache.keys.take(_chartCache.length - 20).toList();
      for (final key in keysToRemove) {
        _chartCache.remove(key);
      }
    }
    
    return chartUrl;
  }

  String _getDetailedChartUrl(String symbol) {
    // 더 큰 크기의 일봉 차트 URL - 캐시 무효화 강화
    final now = DateTime.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000; // 1초 단위
    
    return 'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/day/$symbol.png&t=$secondsSinceEpoch&w=800&h=600&cache=false';
  }

  String _getDetailedChartUrlWithPeriod(String symbol, String period) {
    // 기간별 차트 URL (네이버 파이낸스의 다양한 기간 차트) - 캐시 무효화 강화
    final now = DateTime.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000; // 1초 단위
    
    String chartType = 'day'; // 기본값
    switch (period) {
      case 'year':
        // 1년 차트: 주봉 차트 사용
        chartType = 'week';
        break;
      case 'three':
        // 3년 차트: 월봉 차트 사용
        chartType = 'month';
        break;
      default:
        chartType = 'day';
        break;
    }
    
    return 'https://images.weserv.nl/?url=ssl.pstatic.net/imgfinance/chart/item/candle/$chartType/$symbol.png&t=$secondsSinceEpoch&w=800&h=600&cache=false';
  }

  Widget _buildNewsSection() {
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
                if (_isLoadingNews)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                else
                  Text(
                    '${_newsList.length}개',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoadingNews)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '뉴스를 불러오는 중...',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else if (_newsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  '관련 뉴스가 없습니다',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ...(_newsList.map((news) => _buildNewsItem(news)).toList()),
        ],
      ),
    );
  }

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
                Icon(
                  Icons.open_in_new,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
            if (news.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                news.description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
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
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
                if (news.publishedAt != null)
                  Text(
                    _formatNewsTime(news.publishedAt!),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNewsTime(String publishedAt) {
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
    } catch (e) {
      return '알 수 없음';
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('URL 실행 오류: $e');
    }
  }
}
