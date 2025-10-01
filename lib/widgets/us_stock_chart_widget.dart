import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/chart_scraper_service.dart';

class UsStockChartWidget extends StatefulWidget {
  final String symbol;
  final String? chartUrl;

  const UsStockChartWidget({
    super.key,
    required this.symbol,
    this.chartUrl,
  });

  @override
  State<UsStockChartWidget> createState() => _UsStockChartWidgetState();
}

class _UsStockChartWidgetState extends State<UsStockChartWidget> {
  String? _selectedChartType = 'daily';
  Map<String, String>? _chartUrls;
  bool _isLoading = false;
  String? _error;

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
      _error = null;
    });

    try {
      print('🔍 [Chart Widget] 차트 URL 로드 시작: ${widget.symbol}');
      
      // 차트 스크래핑 서비스를 통해 사용 가능한 차트들 가져오기
      final availableCharts = await ChartScraperService.getAvailableCharts(widget.symbol);
      
      _chartUrls = availableCharts;
      
      // 기본 차트 타입 설정
      if (_chartUrls!.isNotEmpty) {
        _selectedChartType = _chartUrls!.keys.first;
      }

      print('📊 [Chart Widget] 로드된 차트: ${_chartUrls!.keys.toList()}');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ [Chart Widget] 차트 로드 실패: $e');
      setState(() {
        _isLoading = false;
        _error = '차트 데이터를 불러올 수 없습니다: $e';
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
                  '차트 스냅샷 (${widget.symbol})',
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
            else if (_error != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (_chartUrls != null && _selectedChartType != null)
              _buildChartWidget()
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
            if (_chartUrls != null && _selectedChartType != null)
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

  Widget _buildChartWidget() {
    final chartUrl = _chartUrls![_selectedChartType!]!;
    
    // 간단한 차트인 경우
    if (_selectedChartType == 'simple_chart') {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[850],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    color: Colors.blue,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.symbol} 차트',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '차트 데이터를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Yahoo 차트 이미지인 경우
    if (_selectedChartType == 'yahoo_image') {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            chartUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                        'Yahoo 차트를 불러올 수 없습니다',
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
      );
    }
    
    // MarketWatch 차트인 경우
    if (_selectedChartType == 'marketwatch') {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.blue,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'MarketWatch 차트',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '웹에서 전체 차트를 확인하세요',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // TradingView 차트인 경우
    if (_selectedChartType == 'tradingview') {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.blue,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'TradingView 차트',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '웹에서 전체 차트를 확인하세요',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Yahoo Finance API 데이터를 사용한 차트
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[600]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchYahooChartData(chartUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              );
            } else if (snapshot.hasError) {
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
            } else if (snapshot.hasData) {
              return _buildSimpleChart(snapshot.data!);
            } else {
              return Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Text(
                    '차트 데이터 없음',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchYahooChartData(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildSimpleChart(Map<String, dynamic> data) {
    try {
      final chart = data['chart'];
      if (chart == null) return _buildErrorWidget();

      final result = chart['result'] as List?;
      if (result == null || result.isEmpty) return _buildErrorWidget();

      final meta = result[0]['meta'] as Map<String, dynamic>?;
      final quotes = result[0]['indicators']['quote'] as List?;
      
      if (meta == null || quotes == null) return _buildErrorWidget();

      final currentPrice = meta['regularMarketPrice']?.toDouble() ?? 0.0;
      final previousClose = meta['previousClose']?.toDouble() ?? 0.0;
      final change = currentPrice - previousClose;
      final changePercent = previousClose != 0 ? (change / previousClose) * 100 : 0.0;

      return Container(
        color: Colors.grey[850],
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: change >= 0 ? Colors.green : Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: change >= 0 ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  '차트 데이터 로드됨\n${_getChartTypeName(_selectedChartType!)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
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
  }

  String _getChartTypeName(String type) {
    switch (type) {
      case 'simple_chart':
        return '간단한 차트';
      case 'yahoo_image':
        return 'Yahoo 차트 이미지';
      case 'tradingview':
        return 'TradingView 차트';
      case 'marketwatch':
        return 'MarketWatch';
      case 'google_finance':
        return 'Google Finance';
      case 'finviz':
        return 'Finviz';
      case 'investing':
        return 'Investing.com';
      default:
        return type;
    }
  }
}
