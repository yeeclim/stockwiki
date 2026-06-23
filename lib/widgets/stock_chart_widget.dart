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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _chartUrls = {
        'candle':
            'https://ssl.pstatic.net/imgfinance/chart/item/candle/day/${widget.symbol}.png?t=$timestamp',
        'line':
            'https://ssl.pstatic.net/imgfinance/chart/item/area/day/${widget.symbol}.png?t=$timestamp',
        'volume':
            'https://ssl.pstatic.net/imgfinance/chart/item/volume/day/${widget.symbol}.png?t=$timestamp',
      };

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    if (_chartUrls != null)
                      DropdownButton<String>(
                        value: _selectedChartType,
                        dropdownColor: theme.colorScheme.surfaceContainerHigh,
                        style: TextStyle(color: theme.colorScheme.onSurface),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.refresh,
                          color: theme.colorScheme.onSurface),
                      onPressed: _loadChartUrls,
                      tooltip: '실시간 차트 새로고침',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              )
            else if (_chartUrls != null && _selectedChartType != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _chartUrls![_selectedChartType!]!,
                    fit: BoxFit.contain,
                    headers: const {
                      'Cache-Control': 'no-cache, no-store, must-revalidate',
                      'Pragma': 'no-cache',
                      'Expires': '0',
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '차트를 불러올 수 없습니다',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '차트 데이터를 불러오는 중...',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_chartUrls != null)
              Text(
                '차트 타입: ${_getChartTypeName(_selectedChartType!)}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
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
      case 'candle':
        return '일봉 캔들 차트';
      case 'line':
        return '일봉 선 차트';
      case 'volume':
        return '거래량 차트';
      default:
        return type;
    }
  }
}
