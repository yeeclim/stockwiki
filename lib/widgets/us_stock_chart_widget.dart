import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/fmp_service.dart';
import 'dart:math';

class UsStockChartWidget extends StatefulWidget {
  final String symbol;

  const UsStockChartWidget({
    super.key,
    required this.symbol,
  });

  @override
  State<UsStockChartWidget> createState() => _UsStockChartWidgetState();
}

class _UsStockChartWidgetState extends State<UsStockChartWidget> {
  List<Map<String, dynamic>> _historicalData = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '1M'; // 1W, 1M, 3M, 1Y

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 기간에 따른 데이터 개수 조정 (대략적인 값)
      // 1W: 5일, 1M: 22일, 3M: 66일, 1Y: 252일
      // FMPService는 전체 데이터를 가져오므로 받아온 후 자른다.
      final data = await FMPService.fetchHistoricalPrices(widget.symbol);
      
      setState(() {
        _historicalData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '차트 데이터를 불러올 수 없습니다.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterDataByPeriod() {
    if (_historicalData.isEmpty) return [];

    int count;
    switch (_selectedPeriod) {
      case '1W':
        count = 5;
        break;
      case '1M':
        count = 22;
        break;
      case '3M':
        count = 66;
        break;
      case '1Y':
        count = 252;
        break;
      default:
        count = 22;
    }

    // 데이터가 부족하면 전체 반환
    if (_historicalData.length < count) {
      return List.from(_historicalData);
    }
    
    // 최신 데이터가 앞쪽에 있으므로 앞쪽 데이터를 가져온 뒤,
    // 차트 X축은 시간 순서대로 그려야 하므로 다시 역순(오래된 순)으로 정렬해야 함
    // FMPService에서 최신순(내림차순)으로 준다고 가정.
    // _historicalData[0]이 가장 최신 날짜.
    
    final subList = _historicalData.take(count).toList();
    return subList.reversed.toList(); // 오래된 날짜 -> 최신 날짜 순서
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredData = _filterDataByPeriod();

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
                  '${widget.symbol} 주가 차트',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              width: double.infinity, // Ensure chart spans full width
              child: _buildChartContent(filteredData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['1W', '1M', '3M', '1Y'];
    final theme = Theme.of(context);

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPeriod = period;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                period,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected 
                      ? theme.colorScheme.onPrimary 
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartContent(List<Map<String, dynamic>> data) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            TextButton(
              onPressed: _loadChartData,
              child: const Text('다시 시도'),
            )
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '데이터 데이터가 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              child: Text(
                FMPService.debugLog,
                style: const TextStyle(fontSize: 10, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    // 데이터 전처리
    final prices = data.map((e) => (e['close'] as num).toDouble()).toList();
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final priceRange = maxPrice - minPrice;
    final buffer = priceRange * 0.1; // 위아래 여백 10%

    // 상승/하락 색상 결정
    final startPrice = prices.first;
    final endPrice = prices.last;
    final isRising = endPrice >= startPrice;
    final chartColor = isRising ? Colors.redAccent : Colors.blueAccent; 
    // 한국 주식 시장 관습: 상승=빨강, 하락=파랑
    // 미국 주식 시장 관습: 상승=초록, 하락=빨강 (원하면 변경 가능)
    // 여기서는 사용자가 한국인일 가능성이 높으므로 한국식 또는 글로벌(초록/빨강) 선택
    // 테마 색상을 따르도록 수정
    final lineColor = isRising ? const Color(0xFF4CAF50) : const Color(0xFFF44336); // Green / Red

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange / 4, // 4등분
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: max(1, (data.length / 4).floor()).toDouble(), // X축 라벨 간격
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final dateStr = data[index]['date'] as String;
                  // 날짜 포맷팅 (예: 2023-10-25 -> 10/25)
                  try {
                    final date = DateTime.parse(dateStr);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('M/d').format(date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == minPrice - buffer || value == maxPrice + buffer) return const SizedBox.shrink();
                return Text(
                  '\$${value.toStringAsFixed(0)}', // 소수점 제거하여 깔끔하게
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: data.length.toDouble() - 1,
        minY: minPrice - buffer,
        maxY: maxPrice + buffer,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length, (index) {
              return FlSpot(index.toDouble(), prices[index]);
            }),
            isCurved: true,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withOpacity(0.2),
                  lineColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
             getTooltipColor: (touchedSpot) => theme.cardTheme.color!,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index < 0 || index >= data.length) return null;
                
                final item = data[index];
                final date = item['date'];
                final price = item['close'];
                
                return LineTooltipItem(
                  '$date\n\$${price.toStringAsFixed(2)}',
                  theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
            fitInsideHorizontally: true,
            fitInsideVertically: true,
          ),
          handleBuiltInTouches: true, // 터치 핸들링 활성화
        ),
      ),
    );
  }
}
