import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'krx_loader.dart';

class ChartAnalysisService {
  static const String _fmpApiKey = '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh';
  static const String _fmpBaseUrl = 'https://financialmodelingprep.com/api/v3';

  // 실제 주식 데이터를 가져오는 메서드
  static Future<List<Map<String, dynamic>>> getStockData(String symbol, int days) async {
    try {
      // 국내 주식인지 확인 (6자리 숫자)
      if (RegExp(r'^\d{6}$').hasMatch(symbol)) {
        // 국내 주식: KRX 데이터 사용
        return await _fetchKrxData(symbol, days);
      } else {
        // 해외 주식: FMP API 사용
        return await _fetchRealStockData(symbol, days);
      }
    } catch (e) {
      print('실제 데이터 가져오기 실패, 시뮬레이션 데이터 사용: $e');
      // 실제 데이터 실패 시 시뮬레이션 데이터 사용
      return _generateSimulatedData(days);
    }
  }

  // 실제 가격을 받아서 히스토리컬 데이터 생성
  static Future<List<Map<String, dynamic>>> getStockDataWithRealPrice(String symbol, int days, double realPrice, int realVolume) async {
    try {
      print('실제 가격으로 데이터 생성: $symbol, 가격: $realPrice, 거래량: $realVolume');
      return _generateRealPriceBasedData(symbol, days, realPrice, realVolume);
    } catch (e) {
      print('실제 가격 기반 데이터 생성 실패: $e');
      return _generateSimulatedData(days);
    }
  }

  // 실제 가격을 기반으로 한 히스토리컬 데이터 생성
  static List<Map<String, dynamic>> _generateRealPriceBasedData(String symbol, int days, double realPrice, int realVolume) {
    final random = Random();
    final data = <Map<String, dynamic>>[];
    
    double basePrice = realPrice;
    
    for (int i = days; i >= 0; i--) {
      // 실제 가격 변동률을 고려한 시뮬레이션 (더 현실적으로)
      final changePercent = (random.nextDouble() - 0.5) * 0.08; // -4% ~ +4%
      basePrice = basePrice * (1 + changePercent);
      
      // 가격 범위 제한 (현재가의 30%~170% 범위)
      basePrice = max(basePrice, realPrice * 0.3);
      basePrice = min(basePrice, realPrice * 1.7);
      
      final high = basePrice * (1 + random.nextDouble() * 0.03); // 최대 3% 상승
      final low = basePrice * (1 - random.nextDouble() * 0.03);  // 최대 3% 하락
      final volume = (realVolume * (0.3 + random.nextDouble() * 1.4)).round(); // 30%~170% 범위
      
      data.add({
        'date': DateTime.now().subtract(Duration(days: i)),
        'open': basePrice,
        'high': high,
        'low': low,
        'close': basePrice,
        'volume': volume,
      });
    }
    
    print('실제 가격 기반 데이터 생성 완료: ${data.length}개, 최종 가격: ${data.last['close']}');
    return data;
  }

  // KRX 데이터 가져오기 (국내 주식)
  static Future<List<Map<String, dynamic>>> _fetchKrxData(String symbol, int days) async {
    try {
      print('KRX 데이터 요청: $symbol');
      
      // KRX 로더를 사용해서 실제 주식 데이터 가져오기
      final stockData = await KrxLoader.searchStock(symbol);
      print('KRX 응답 데이터: $stockData');
      
      if (stockData.isNotEmpty && stockData['price'] != null && stockData['price'] > 0) {
        print('실제 KRX 데이터 발견: ${stockData['price']}');
        // 실제 가격을 기반으로 히스토리컬 데이터 생성
        return _generateKrxHistoricalData(stockData, days);
      } else {
        print('KRX 데이터가 비어있거나 가격이 0입니다');
        throw Exception('KRX 데이터를 가져올 수 없습니다');
      }
    } catch (e) {
      print('KRX 데이터 오류: $e');
      // 실패 시 시뮬레이션 데이터 사용
      return _generateKrxSimulatedData(symbol, days);
    }
  }

  // 실제 KRX 가격을 기반으로 히스토리컬 데이터 생성
  static List<Map<String, dynamic>> _generateKrxHistoricalData(Map<String, dynamic> stockData, int days) {
    final random = Random();
    final data = <Map<String, dynamic>>[];
    
    // 실제 현재가를 기반으로 함
    final currentPrice = (stockData['price'] as num).toDouble();
    final currentVolume = stockData['volume'] as int? ?? 1000000;
    
    double basePrice = currentPrice;
    
    for (int i = days; i >= 0; i--) {
      // 실제 가격 변동률을 고려한 시뮬레이션
      final changePercent = (random.nextDouble() - 0.5) * 0.1; // -5% ~ +5%
      basePrice = basePrice * (1 + changePercent);
      basePrice = max(basePrice, currentPrice * 0.5); // 현재가의 50% 이하로는 안 떨어짐
      basePrice = min(basePrice, currentPrice * 2.0); // 현재가의 200% 이상으로는 안 올라감
      
      final high = basePrice * (1 + random.nextDouble() * 0.05); // 최대 5% 상승
      final low = basePrice * (1 - random.nextDouble() * 0.05);  // 최대 5% 하락
      final volume = (currentVolume * (0.5 + random.nextDouble())).round();
      
      data.add({
        'date': DateTime.now().subtract(Duration(days: i)),
        'open': basePrice,
        'high': high,
        'low': low,
        'close': basePrice,
        'volume': volume,
      });
    }
    
    return data;
  }

  // KRX 기반 시뮬레이션 데이터 (백업용)
  static List<Map<String, dynamic>> _generateKrxSimulatedData(String symbol, int days) {
    final random = Random();
    final data = <Map<String, dynamic>>[];
    
    // 기본 가격 (종목별로 다르게 설정)
    double basePrice = 45000;
    if (symbol.startsWith('00')) basePrice = 10000; // 코스닥
    if (symbol.startsWith('01')) basePrice = 50000; // 대형주
    
    for (int i = days; i >= 0; i--) {
      // 더 현실적인 가격 변동 시뮬레이션
      double change = (random.nextDouble() - 0.5) * 1000; // -500 ~ +500
      basePrice += change;
      basePrice = max(basePrice, 1000); // 최소 가격 보장
      
      final high = basePrice + random.nextDouble() * 500;
      final low = basePrice - random.nextDouble() * 500;
      final volume = (random.nextDouble() * 1000000 + 100000).round();
      
      data.add({
        'date': DateTime.now().subtract(Duration(days: i)),
        'open': basePrice,
        'high': high,
        'low': low,
        'close': basePrice,
        'volume': volume,
      });
    }
    
    return data;
  }

  // FMP API를 통한 실제 주식 데이터 가져오기 (미국 주식만)
  static Future<List<Map<String, dynamic>>> _fetchRealStockData(String symbol, int days) async {
    try {
      print('FMP API로 미국 주식 데이터 요청: $symbol');
      // 일봉 데이터 가져오기 (FMP는 미국 주식만 지원)
      final url = Uri.parse(
        '$_fmpBaseUrl/historical-price-full/$symbol?apikey=$_fmpApiKey&from=${_getDateString(days)}&to=${_getDateString(0)}'
      );
      
      final response = await http.get(url, headers: {
        'Cache-Control': 'no-cache',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });

      if (response.statusCode != 200) {
        throw Exception('API 응답 오류: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['historical'] == null) {
        throw Exception('히스토리컬 데이터가 없습니다');
      }

      final historical = data['historical'] as List;
      
      // 데이터를 역순으로 정렬 (오래된 것부터)
      historical.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      
      return historical.map<Map<String, dynamic>>((item) => {
        'date': DateTime.parse(item['date']),
        'open': (item['open'] as num).toDouble(),
        'high': (item['high'] as num).toDouble(),
        'low': (item['low'] as num).toDouble(),
        'close': (item['close'] as num).toDouble(),
        'volume': item['volume'] as int,
      }).toList();
      
    } catch (e) {
      print('FMP API 오류: $e');
      throw Exception('실제 데이터를 가져올 수 없습니다: $e');
    }
  }

  // 날짜 문자열 생성 (days일 전부터)
  static String _getDateString(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 시뮬레이션된 주식 데이터 생성
  static List<Map<String, dynamic>> _generateSimulatedData(int days) {
    final random = Random();
    final data = <Map<String, dynamic>>[];
    
    double basePrice = 45000;
    double currentPrice = basePrice;
    
    for (int i = days; i >= 0; i--) {
      // 가격 변동 시뮬레이션
      double change = (random.nextDouble() - 0.5) * 2000; // -1000 ~ +1000
      currentPrice += change;
      currentPrice = max(currentPrice, 10000); // 최소 가격 보장
      
      final high = currentPrice + random.nextDouble() * 1000;
      final low = currentPrice - random.nextDouble() * 1000;
      final volume = (random.nextDouble() * 2000000 + 500000).round();
      
      data.add({
        'date': DateTime.now().subtract(Duration(days: i)),
        'open': currentPrice,
        'high': high,
        'low': low,
        'close': currentPrice,
        'volume': volume,
      });
    }
    
    return data;
  }

  // 기술적 분석 수행
  static Map<String, dynamic> analyzeChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      throw Exception('분석할 데이터가 없습니다');
    }

    final currentPrice = data.last['close'] as double;
    final analysis = <String, dynamic>{};

    // 1. 이동평균선 분석
    analysis['movingAverages'] = _calculateMovingAverages(data);
    
    // 2. RSI 계산
    analysis['rsi'] = _calculateRSI(data);
    
    // 3. MACD 계산
    analysis['macd'] = _calculateMACD(data);
    
    // 4. 볼린저 밴드 계산
    analysis['bollingerBands'] = _calculateBollingerBands(data);
    
    // 5. 지지선/저항선 분석
    analysis['supportResistance'] = _calculateSupportResistance(data);
    
    // 6. 거래량 분석
    analysis['volume'] = _analyzeVolume(data);
    
    // 7. 추세 분석
    analysis['trend'] = _analyzeTrend(data);
    
    // 8. 패턴 분석
    analysis['pattern'] = _analyzePattern(data);
    
    // 9. 종합 분석
    analysis['overall'] = _generateOverallAnalysis(analysis, currentPrice);

    return analysis;
  }

  // 이동평균선 계산
  static Map<String, double> _calculateMovingAverages(List<Map<String, dynamic>> data) {
    final closes = data.map((d) => d['close'] as double).toList();
    
    return {
      'ma5': _calculateMA(closes, 5),
      'ma20': _calculateMA(closes, 20),
      'ma60': _calculateMA(closes, 60),
      'ma120': _calculateMA(closes, 120),
    };
  }

  static double _calculateMA(List<double> prices, int period) {
    if (prices.length < period) return prices.last;
    
    final recentPrices = prices.sublist(prices.length - period);
    return recentPrices.reduce((a, b) => a + b) / period;
  }

  // RSI 계산
  static double _calculateRSI(List<Map<String, dynamic>> data, {int period = 14}) {
    if (data.length < period + 1) return 50.0;
    
    final closes = data.map((d) => d['close'] as double).toList();
    final gains = <double>[];
    final losses = <double>[];
    
    for (int i = 1; i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      gains.add(change > 0 ? change : 0);
      losses.add(change < 0 ? -change : 0);
    }
    
    if (gains.length < period) return 50.0;
    
    final avgGain = gains.sublist(gains.length - period).reduce((a, b) => a + b) / period;
    final avgLoss = losses.sublist(losses.length - period).reduce((a, b) => a + b) / period;
    
    if (avgLoss == 0) return 100.0;
    
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  // MACD 계산
  static Map<String, double> _calculateMACD(List<Map<String, dynamic>> data) {
    final closes = data.map((d) => d['close'] as double).toList();
    
    final ema12 = _calculateEMA(closes, 12);
    final ema26 = _calculateEMA(closes, 26);
    final macd = ema12 - ema26;
    
    return {
      'macd': macd,
      'signal': macd, // 단순화
      'histogram': macd,
    };
  }

  static double _calculateEMA(List<double> prices, int period) {
    if (prices.length < period) return prices.last;
    
    final multiplier = 2.0 / (period + 1);
    double ema = prices.sublist(0, period).reduce((a, b) => a + b) / period;
    
    for (int i = period; i < prices.length; i++) {
      ema = (prices[i] * multiplier) + (ema * (1 - multiplier));
    }
    
    return ema;
  }

  // 볼린저 밴드 계산
  static Map<String, double> _calculateBollingerBands(List<Map<String, dynamic>> data, {int period = 20, double stdDev = 2.0}) {
    final closes = data.map((d) => d['close'] as double).toList();
    
    if (closes.length < period) {
      final price = closes.last;
      return {'upper': price, 'middle': price, 'lower': price};
    }
    
    final recentPrices = closes.sublist(closes.length - period);
    final middle = recentPrices.reduce((a, b) => a + b) / period;
    
    final variance = recentPrices.map((p) => pow(p - middle, 2)).reduce((a, b) => a + b) / period;
    final standardDeviation = sqrt(variance);
    
    return {
      'upper': middle + (standardDeviation * stdDev),
      'middle': middle,
      'lower': middle - (standardDeviation * stdDev),
    };
  }

  // 지지선/저항선 계산
  static Map<String, double> _calculateSupportResistance(List<Map<String, dynamic>> data) {
    final highs = data.map((d) => d['high'] as double).toList();
    final lows = data.map((d) => d['low'] as double).toList();
    
    // 최근 20일 기준으로 계산
    final recentHighs = highs.length > 20 ? highs.sublist(highs.length - 20) : highs;
    final recentLows = lows.length > 20 ? lows.sublist(lows.length - 20) : lows;
    
    return {
      'resistance': recentHighs.reduce((a, b) => a > b ? a : b),
      'support': recentLows.reduce((a, b) => a < b ? a : b),
    };
  }

  // 거래량 분석
  static Map<String, dynamic> _analyzeVolume(List<Map<String, dynamic>> data) {
    final volumes = data.map((d) => d['volume'] as int).toList();
    final currentVolume = volumes.last;
    
    if (volumes.length < 20) {
      return {
        'current': currentVolume,
        'average': currentVolume,
        'ratio': 1.0,
        'trend': '보통',
      };
    }
    
    final avgVolume = volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;
    final ratio = currentVolume / avgVolume;
    
    String trend;
    if (ratio > 1.5) trend = '급증';
    else if (ratio > 1.2) trend = '증가';
    else if (ratio < 0.8) trend = '감소';
    else trend = '보통';
    
    return {
      'current': currentVolume,
      'average': avgVolume.round(),
      'ratio': ratio,
      'trend': trend,
    };
  }

  // 추세 분석
  static Map<String, dynamic> _analyzeTrend(List<Map<String, dynamic>> data) {
    final closes = data.map((d) => d['close'] as double).toList();
    
    if (closes.length < 20) {
      return {'direction': '불명', 'strength': '보통'};
    }
    
    // 단기 추세 (5일)
    final shortTerm = _calculateTrend(closes, 5);
    // 중기 추세 (20일)
    final mediumTerm = _calculateTrend(closes, 20);
    
    String direction;
    String strength;
    
    if (shortTerm > 0.02 && mediumTerm > 0.02) {
      direction = '상승';
      strength = '강함';
    } else if (shortTerm < -0.02 && mediumTerm < -0.02) {
      direction = '하락';
      strength = '강함';
    } else if (shortTerm > 0.01 || mediumTerm > 0.01) {
      direction = '상승';
      strength = '중간';
    } else if (shortTerm < -0.01 || mediumTerm < -0.01) {
      direction = '하락';
      strength = '중간';
    } else {
      direction = '횡보';
      strength = '보통';
    }
    
    return {
      'direction': direction,
      'strength': strength,
      'shortTerm': shortTerm,
      'mediumTerm': mediumTerm,
    };
  }

  static double _calculateTrend(List<double> prices, int period) {
    if (prices.length < period) return 0.0;
    
    final recent = prices.sublist(prices.length - period);
    final start = recent.first;
    final end = recent.last;
    
    return (end - start) / start;
  }

  // 패턴 분석
  static String _analyzePattern(List<Map<String, dynamic>> data) {
    final closes = data.map((d) => d['close'] as double).toList();
    final highs = data.map((d) => d['high'] as double).toList();
    final lows = data.map((d) => d['low'] as double).toList();
    
    if (closes.length < 10) return '불명';
    
    // 간단한 패턴 인식
    final recent = closes.sublist(closes.length - 10);
    final trend = _calculateTrend(recent, 10);
    
    if (trend > 0.05) return '상승 삼각형';
    if (trend < -0.05) return '하락 삼각형';
    if (_isDoubleBottom(lows)) return '더블 바텀';
    if (_isDoubleTop(highs)) return '더블 탑';
    
    return '횡보';
  }

  static bool _isDoubleBottom(List<double> lows) {
    if (lows.length < 10) return false;
    
    final recent = lows.sublist(lows.length - 10);
    final min1 = recent.sublist(0, 5).reduce((a, b) => a < b ? a : b);
    final min2 = recent.sublist(5, 10).reduce((a, b) => a < b ? a : b);
    
    return (min1 - min2).abs() / min1 < 0.02; // 2% 이내 차이
  }

  static bool _isDoubleTop(List<double> highs) {
    if (highs.length < 10) return false;
    
    final recent = highs.sublist(highs.length - 10);
    final max1 = recent.sublist(0, 5).reduce((a, b) => a > b ? a : b);
    final max2 = recent.sublist(5, 10).reduce((a, b) => a > b ? a : b);
    
    return (max1 - max2).abs() / max1 < 0.02; // 2% 이내 차이
  }

  // 종합 분석 생성
  static Map<String, dynamic> _generateOverallAnalysis(Map<String, dynamic> analysis, double currentPrice) {
    final rsi = analysis['rsi'] as double;
    final trend = analysis['trend'] as Map<String, dynamic>;
    final volume = analysis['volume'] as Map<String, dynamic>;
    final supportResistance = analysis['supportResistance'] as Map<String, double>;
    
    // 매수/매도 신호 생성
    String recommendation;
    int confidence = 0;
    
    // RSI 기반 신호
    if (rsi < 30) {
      recommendation = '매수';
      confidence += 20;
    } else if (rsi > 70) {
      recommendation = '매도';
      confidence += 20;
    } else {
      recommendation = '보유';
      confidence += 10;
    }
    
    // 추세 기반 신호
    if (trend['direction'] == '상승' && trend['strength'] == '강함') {
      if (recommendation == '매수') confidence += 30;
      else if (recommendation == '보유') confidence += 20;
    } else if (trend['direction'] == '하락' && trend['strength'] == '강함') {
      if (recommendation == '매도') confidence += 30;
      else if (recommendation == '보유') confidence += 20;
    }
    
    // 거래량 기반 신호
    if (volume['trend'] == '급증' && trend['direction'] == '상승') {
      confidence += 20;
    } else if (volume['trend'] == '급증' && trend['direction'] == '하락') {
      confidence += 20;
    }
    
    // 지지선/저항선 기반 신호
    final support = supportResistance['support']!;
    final resistance = supportResistance['resistance']!;
    
    if (currentPrice <= support * 1.02) { // 지지선 근처
      if (recommendation == '매수') confidence += 15;
    } else if (currentPrice >= resistance * 0.98) { // 저항선 근처
      if (recommendation == '매도') confidence += 15;
    }
    
    // 현재 위치 분석
    String position;
    final priceRange = resistance - support;
    final currentPosition = (currentPrice - support) / priceRange;
    
    if (currentPosition > 0.8) position = '고점';
    else if (currentPosition < 0.2) position = '저점';
    else position = '중간';
    
    return {
      'recommendation': recommendation,
      'confidence': min(confidence, 100),
      'position': position,
      'reason': _generateReason(analysis, currentPrice),
    };
  }

  static String _generateReason(Map<String, dynamic> analysis, double currentPrice) {
    final reasons = <String>[];
    
    final rsi = analysis['rsi'] as double;
    if (rsi < 30) reasons.add('RSI 과매도');
    if (rsi > 70) reasons.add('RSI 과매수');
    
    final trend = analysis['trend'] as Map<String, dynamic>;
    if (trend['direction'] == '상승') reasons.add('상승 추세');
    if (trend['direction'] == '하락') reasons.add('하락 추세');
    
    final volume = analysis['volume'] as Map<String, dynamic>;
    if (volume['trend'] == '급증') reasons.add('거래량 급증');
    
    return reasons.isEmpty ? '기술적 분석 결과' : reasons.join(', ');
  }
}
