import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WtiWidget extends StatefulWidget {
  const WtiWidget({super.key});

  @override
  State<WtiWidget> createState() => _WtiWidgetState();
}

class _WtiWidgetState extends State<WtiWidget> {
  double? _wtiPrice;
  String? _date;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchWtiPrice();
  }

  // 캐시된 가격 로드
  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('wti_price');
      final cachedDate = prefs.getString('wti_date');
      final cacheTime = prefs.getInt('wti_cache_time');
      
      if (cachedPrice != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 10분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 10 * 60 * 1000) {
          setState(() {
            _wtiPrice = cachedPrice;
            _date = cachedDate;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 캐시 로드 실패 시 무시
    }
  }

  // 가격 캐시 저장
  Future<void> _cachePrice(double price, String? date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wti_price', price);
      if (date != null) await prefs.setString('wti_date', date);
      await prefs.setInt('wti_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
  }

  Future<void> _fetchWtiPrice() async {
    // 여러 API를 병렬로 호출하고 첫 번째 유효한 값 사용
    try {
      final results = await Future.wait([
        _tryYahooFinance(),
        _tryEIA(),
        _tryAlternativeAPI(),
      ], eagerError: false).timeout(const Duration(seconds: 5));

      // 첫 번째 유효한 가격 찾기
      for (final result in results) {
        if (result != null && result['price'] != null && result['price']! > 0) {
          setState(() {
            _wtiPrice = result['price'];
            _date = result['date'];
            _isLoading = false;
          });
          await _cachePrice(result['price']!, result['date']);
          return;
        }
      }
    } catch (e) {
      // 병렬 호출 실패 시, 폴백 가격 사용
      try {
        final fallbackPrice = _getFallbackPrice();
        if (fallbackPrice > 0) {
          setState(() {
            _wtiPrice = fallbackPrice;
            _date = 'Estimated';
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        // 폴백도 실패
      }
    }

    // 모든 시도 실패 시
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  // Yahoo Finance - WTI Crude Oil Futures (CL=F)
  Future<Map<String, dynamic>?> _tryYahooFinance() async {
    try {
      final response = await http.get(
        Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/CL=F'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          if (meta != null) {
            final price = meta?['regularMarketPrice'] ?? 
                         meta?['previousClose'];
            if (price != null) {
              return {
                'price': price.toDouble(),
                'date': 'Latest',
              };
            }
          }
        }
      }
    } catch (e) {
      // Yahoo Finance error
    }
    return null;
  }

  // EIA API (기존)
  Future<Map<String, dynamic>?> _tryEIA() async {
    try {
      const apiKey = '4X0kMGDGQo7wdJ0BAtVJ3PygI15g8GdiVQsCpeGt';
      const url = 'https://api.eia.gov/v2/seriesid/PET.RWTC.D?api_key=$apiKey';

      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latest = data['response']['data'][0];
        final price = latest['value']?.toDouble();
        final date = latest['period'];

        if (price != null) {
          return {
            'price': price,
            'date': date,
          };
        }
      }
    } catch (e) {
      // EIA API error
    }
    return null;
  }

  // Alternative API - Commodities API나 다른 소스
  Future<Map<String, dynamic>?> _tryAlternativeAPI() async {
    try {
      // OANDA API 사용 (무료)
      final response = await http.get(
        Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/BZ=F'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          if (meta != null) {
            final price = meta?['regularMarketPrice'] ?? 
                         meta?['previousClose'];
            if (price != null) {
              // Brent는 WTI보다 약간 높으므로 조정
              return {
                'price': (price.toDouble() * 0.95), // 대략적 조정
                'date': 'Estimated',
              };
            }
          }
        }
      }
    } catch (e) {
      // Alternative API error
    }
    return null;
  }

  // 폴백 가격 (2025년 1월 기준 대략적인 WTI 가격)
  double _getFallbackPrice() {
    return 73.5; // USD per barrel (2025년 1월 평균 기준)
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 80,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'WTI 유가 (USD/bbl)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          _wtiPrice != null ? '\$${_wtiPrice!.toStringAsFixed(2)}' : 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_date != null)
                          Text(
                            _date!,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}
