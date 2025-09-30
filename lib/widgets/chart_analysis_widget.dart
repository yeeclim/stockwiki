import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/chart_analysis_service.dart';

class ChartAnalysisWidget extends StatefulWidget {
  final String symbol;
  final String stockName;
  final double? currentPrice;
  final int? volume;

  const ChartAnalysisWidget({
    super.key,
    required this.symbol,
    required this.stockName,
    this.currentPrice,
    this.volume,
  });

  @override
  State<ChartAnalysisWidget> createState() => _ChartAnalysisWidgetState();
}

class _ChartAnalysisWidgetState extends State<ChartAnalysisWidget> {
  Map<String, dynamic>? _analysisResult;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzeChart();
  }

  Future<void> _analyzeChart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // StockCard에서 전달받은 실제 가격이 있으면 사용
      if (widget.currentPrice != null && widget.currentPrice! > 0) {
        print('=== 차트 분석 디버깅 ===');
        print('종목: ${widget.symbol}');
        print('종목명: ${widget.stockName}');
        print('StockCard에서 받은 가격: ${widget.currentPrice}');
        print('StockCard에서 받은 거래량: ${widget.volume}');
        print('========================');
        
        final stockData = await ChartAnalysisService.getStockDataWithRealPrice(
          widget.symbol, 
          120, 
          widget.currentPrice!, 
          widget.volume ?? 1000000
        );
        print('생성된 히스토리컬 데이터 개수: ${stockData.length}');
        print('최종 가격: ${stockData.last['close']}');
        
        final analysis = ChartAnalysisService.analyzeChart(stockData);
        final result = _buildAnalysisResult(stockData, analysis, true);
        
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      } else {
        // 실제 주식 데이터 가져오기
        final stockData = await ChartAnalysisService.getStockData(widget.symbol, 120);
        final analysis = ChartAnalysisService.analyzeChart(stockData);
        final result = _buildAnalysisResult(stockData, analysis, false);
        
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '분석 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildAnalysisResult(List<Map<String, dynamic>> stockData, Map<String, dynamic> analysis, bool isRealData) {
    // 강제로 실제 가격만 사용 (문제 해결을 위해)
    final currentPrice = widget.currentPrice ?? 0.0;
    
    // 전일 가격은 히스토리컬 데이터에서 가져오되, 실제 가격 기반으로 조정
    final previousPrice = stockData.length > 1 ? stockData[stockData.length - 2]['close'] as double : currentPrice;
    final priceChange = currentPrice - previousPrice;
    final priceChangePercent = (priceChange / previousPrice) * 100;
    
    print('=== 강제 실제 가격 사용 ===');
    print('widget.currentPrice: ${widget.currentPrice}');
    print('stockData.last[close]: ${stockData.last['close']}');
    print('강제 사용할 currentPrice: $currentPrice');
    print('========================');
    
    // 시간대별 분석 (다양한 기간의 데이터로 분석)
    final timeframes = <String, Map<String, dynamic>>{};
    
    // 1일 분석
    if (stockData.length >= 1) {
      final day1Data = stockData.sublist(stockData.length - 1);
      final day1Analysis = ChartAnalysisService.analyzeChart(day1Data);
      timeframes['1day'] = {
        'trend': day1Analysis['trend']['direction'],
        'strength': day1Analysis['trend']['strength'],
      };
    }
    
    // 1주 분석
    if (stockData.length >= 7) {
      final week1Data = stockData.sublist(stockData.length - 7);
      final week1Analysis = ChartAnalysisService.analyzeChart(week1Data);
      timeframes['1week'] = {
        'trend': week1Analysis['trend']['direction'],
        'strength': week1Analysis['trend']['strength'],
      };
    }
    
    // 1개월 분석
    if (stockData.length >= 30) {
      final month1Data = stockData.sublist(stockData.length - 30);
      final month1Analysis = ChartAnalysisService.analyzeChart(month1Data);
      timeframes['1month'] = {
        'trend': month1Analysis['trend']['direction'],
        'strength': month1Analysis['trend']['strength'],
      };
    }
    
    // 3개월 분석
    if (stockData.length >= 90) {
      final month3Data = stockData.sublist(stockData.length - 90);
      final month3Analysis = ChartAnalysisService.analyzeChart(month3Data);
      timeframes['3month'] = {
        'trend': month3Analysis['trend']['direction'],
        'strength': month3Analysis['trend']['strength'],
      };
    }
    
    // 1년 분석
    if (stockData.length >= 120) {
      final year1Data = stockData.sublist(stockData.length - 120);
      final year1Analysis = ChartAnalysisService.analyzeChart(year1Data);
      timeframes['1year'] = {
        'trend': year1Analysis['trend']['direction'],
        'strength': year1Analysis['trend']['strength'],
      };
    }
    
    return {
      'currentPrice': currentPrice.round(),
      'priceChange': priceChange.round(),
      'priceChangePercent': priceChangePercent,
      'analysis': {
        'trend': analysis['trend']['direction'],
        'strength': analysis['trend']['strength'],
        'position': analysis['overall']['position'],
        'support': analysis['supportResistance']['support'].round(),
        'resistance': analysis['supportResistance']['resistance'].round(),
        'rsi': analysis['rsi'],
        'macd': analysis['macd']['macd'] > 0 ? '상승' : '하락',
        'volume': analysis['volume']['trend'],
        'pattern': analysis['pattern'],
        'recommendation': analysis['overall']['recommendation'],
        'confidence': analysis['overall']['confidence'],
      },
      'timeframes': timeframes,
      'indicators': {
        'movingAverage': {
          'ma5': analysis['movingAverages']['ma5'].round(),
          'ma20': analysis['movingAverages']['ma20'].round(),
          'ma60': analysis['movingAverages']['ma60'].round(),
          'ma120': analysis['movingAverages']['ma120'].round(),
        },
        'bollinger': {
          'upper': analysis['bollingerBands']['upper'].round(),
          'middle': analysis['bollingerBands']['middle'].round(),
          'lower': analysis['bollingerBands']['lower'].round(),
        },
        'volume': {
          'current': analysis['volume']['current'],
          'average': analysis['volume']['average'],
          'ratio': analysis['volume']['ratio'],
        }
      }
    };
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
                  '${widget.stockName} 차트 분석',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  onPressed: _analyzeChart,
                  icon: const Icon(Icons.refresh, color: Colors.white),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            else if (_analysisResult != null)
              _buildAnalysisContent()
            else
              const Center(
                child: Text(
                  '분석 데이터를 불러오는 중...',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    final analysis = _analysisResult!['analysis'] as Map<String, dynamic>;
    final currentPrice = _analysisResult!['currentPrice'] as int;
    final priceChange = _analysisResult!['priceChange'] as int;
    final priceChangePercent = _analysisResult!['priceChangePercent'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 가격 및 변동률
        _buildPriceSection(currentPrice, priceChange, priceChangePercent),
        const SizedBox(height: 16),
        
        // 주요 분석 결과
        _buildMainAnalysis(analysis),
        const SizedBox(height: 16),
        
        // 시간대별 분석
        _buildTimeframeAnalysis(),
        const SizedBox(height: 16),
        
        // 기술적 지표
        _buildTechnicalIndicators(),
      ],
    );
  }

  Widget _buildPriceSection(int currentPrice, int priceChange, double priceChangePercent) {
    final isPositive = priceChange >= 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '현재가 (실제)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '${currentPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 디버깅용 실제 가격 표시
              if (widget.currentPrice != null && widget.currentPrice! > 0)
                Text(
                  '원본: ${widget.currentPrice!.toStringAsFixed(0)}원',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              // 문제 진단용 추가 정보
              Text(
                '분석가격: ${currentPrice.toStringAsFixed(0)}원',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
              Text(
                '차이: ${(currentPrice - (widget.currentPrice ?? 0)).toStringAsFixed(0)}원',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '전일 대비',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.red : Colors.blue,
                    size: 16,
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${priceChange.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                    style: TextStyle(
                      color: isPositive ? Colors.red : Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${isPositive ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? Colors.red : Colors.blue,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainAnalysis(Map<String, dynamic> analysis) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주요 분석 결과',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalysisRow('추세', analysis['trend'], _getTrendColor(analysis['trend'])),
          _buildAnalysisRow('강도', analysis['strength'], _getStrengthColor(analysis['strength'])),
          _buildAnalysisRow('위치', analysis['position'], _getPositionColor(analysis['position'])),
          _buildAnalysisRow('패턴', analysis['pattern'], Colors.white),
          _buildAnalysisRow('추천', analysis['recommendation'], _getRecommendationColor(analysis['recommendation'])),
          _buildAnalysisRow('신뢰도', '${analysis['confidence']}%', _getConfidenceColor(analysis['confidence'])),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeAnalysis() {
    final timeframes = _analysisResult!['timeframes'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시간대별 분석',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...timeframes.entries.map((entry) {
            final timeframe = _getTimeframeName(entry.key);
            final data = entry.value as Map<String, dynamic>;
            return _buildTimeframeRow(timeframe, data['trend'], data['strength']);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimeframeRow(String timeframe, String trend, String strength) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeframe,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              Text(
                trend,
                style: TextStyle(
                  color: _getTrendColor(trend),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strength,
                style: TextStyle(
                  color: _getStrengthColor(strength),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalIndicators() {
    final indicators = _analysisResult!['indicators'] as Map<String, dynamic>;
    final ma = indicators['movingAverage'] as Map<String, dynamic>;
    final bollinger = indicators['bollinger'] as Map<String, dynamic>;
    final volume = indicators['volume'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기술적 지표',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildIndicatorRow('MA5', ma['ma5'], Colors.yellow),
          _buildIndicatorRow('MA20', ma['ma20'], Colors.orange),
          _buildIndicatorRow('MA60', ma['ma60'], Colors.purple),
          _buildIndicatorRow('MA120', ma['ma120'], Colors.blue),
          const Divider(color: Colors.grey),
          _buildIndicatorRow('볼린저 상단', bollinger['upper'], Colors.red),
          _buildIndicatorRow('볼린저 중간', bollinger['middle'], Colors.white),
          _buildIndicatorRow('볼린저 하단', bollinger['lower'], Colors.blue),
          const Divider(color: Colors.grey),
          _buildIndicatorRow('거래량 비율', '${volume['ratio']}배', _getVolumeColor(volume['ratio'])),
        ],
      ),
    );
  }

  Widget _buildIndicatorRow(String label, dynamic value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value is int ? '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원' : value.toString(),
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 색상 결정 함수들
  Color _getTrendColor(String trend) {
    switch (trend) {
      case '상승': return Colors.red;
      case '하락': return Colors.blue;
      case '횡보': return Colors.yellow;
      default: return Colors.white;
    }
  }

  Color _getStrengthColor(String strength) {
    switch (strength) {
      case '강함': return Colors.red;
      case '중간': return Colors.yellow;
      case '약함': return Colors.blue;
      default: return Colors.white;
    }
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case '고점': return Colors.red;
      case '중간': return Colors.yellow;
      case '저점': return Colors.blue;
      default: return Colors.white;
    }
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation) {
      case '매수': return Colors.red;
      case '보유': return Colors.yellow;
      case '매도': return Colors.blue;
      default: return Colors.white;
    }
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.red;
    if (confidence >= 60) return Colors.yellow;
    return Colors.blue;
  }

  Color _getVolumeColor(double ratio) {
    if (ratio >= 1.5) return Colors.red;
    if (ratio >= 1.0) return Colors.yellow;
    return Colors.blue;
  }

  String _getTimeframeName(String key) {
    switch (key) {
      case '1day': return '1일';
      case '1week': return '1주';
      case '1month': return '1개월';
      case '3month': return '3개월';
      case '1year': return '1년';
      default: return key;
    }
  }
}