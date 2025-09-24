import 'package:flutter/material.dart';

class StockChartWidget extends StatefulWidget {
  final String symbol;
  final String? chartUrl;

  const StockChartWidget({
    super.key,
    required this.symbol,
    this.chartUrl,
  });

  @override
  State<StockChartWidget> createState() => _StockChartWidgetState();
}

class _StockChartWidgetState extends State<StockChartWidget> {
  String? _selectedChartType = 'daily';
  Map<String, String>? _chartUrls;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.chartUrl != null) {
      _chartUrls = {'daily': widget.chartUrl!};
    } else {
      _loadChartUrls();
    }
  }

  Future<void> _loadChartUrls() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final baseUrl = Uri.base.origin;
      final response = await Future.wait([
        Future.delayed(Duration(milliseconds: 500)), // 로딩 시뮬레이션
      ]);

      // 네이버 증권 차트 URL 생성 (실제 작동하는 URL들)
      _chartUrls = {
        'daily': 'https://ssl.pstatic.net/imgfinance/chart/item/area/day/${widget.symbol}.png',
        'weekly': 'https://ssl.pstatic.net/imgfinance/chart/item/area/week/${widget.symbol}.png',
        'monthly': 'https://ssl.pstatic.net/imgfinance/chart/item/area/month/${widget.symbol}.png',
        'candle': 'https://ssl.pstatic.net/imgfinance/chart/item/candle/day/${widget.symbol}.png',
        'candle_weekly': 'https://ssl.pstatic.net/imgfinance/chart/item/candle/week/${widget.symbol}.png',
        'candle_monthly': 'https://ssl.pstatic.net/imgfinance/chart/item/candle/month/${widget.symbol}.png',
        'volume': 'https://ssl.pstatic.net/imgfinance/chart/item/volume/day/${widget.symbol}.png',
        'minute5': 'https://ssl.pstatic.net/imgfinance/chart/item/area/minute5/${widget.symbol}.png',
        'minute15': 'https://ssl.pstatic.net/imgfinance/chart/item/area/minute15/${widget.symbol}.png',
        'minute30': 'https://ssl.pstatic.net/imgfinance/chart/item/area/minute30/${widget.symbol}.png',
        'minute60': 'https://ssl.pstatic.net/imgfinance/chart/item/area/minute60/${widget.symbol}.png',
        'technical': 'https://ssl.pstatic.net/imgfinance/chart/item/technical/day/${widget.symbol}.png',
        'line': 'https://ssl.pstatic.net/imgfinance/chart/item/line/day/${widget.symbol}.png',
        'bar': 'https://ssl.pstatic.net/imgfinance/chart/item/bar/day/${widget.symbol}.png',
      };

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '차트 스냅샷',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_chartUrls != null)
                  DropdownButton<String>(
                    value: _selectedChartType,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    items: _chartUrls!.keys.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_getChartTypeName(type)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedChartType = newValue;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            else if (_chartUrls != null && _selectedChartType != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _chartUrls![_selectedChartType!]!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '차트를 불러올 수 없습니다',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '차트 데이터를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_chartUrls != null)
              Text(
                '차트 타입: ${_getChartTypeName(_selectedChartType!)}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getChartTypeName(String type) {
    switch (type) {
      case 'daily':
        return '일봉(Area)';
      case 'weekly':
        return '주봉(Area)';
      case 'monthly':
        return '월봉(Area)';
      case 'candle':
        return '일봉(캔들)';
      case 'candle_weekly':
        return '주봉(캔들)';
      case 'candle_monthly':
        return '월봉(캔들)';
      case 'volume':
        return '거래량';
      case 'minute5':
        return '5분봉';
      case 'minute15':
        return '15분봉';
      case 'minute30':
        return '30분봉';
      case 'minute60':
        return '60분봉';
      case 'technical':
        return '기술적지표';
      case 'line':
        return '라인차트';
      case 'bar':
        return '바차트';
      default:
        return type;
    }
  }
}
