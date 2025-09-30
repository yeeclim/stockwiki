import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SilverWidget extends StatefulWidget {
  const SilverWidget({super.key});

  @override
  State<SilverWidget> createState() => _SilverWidgetState();
}

class _SilverWidgetState extends State<SilverWidget> {
  double? _silverPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchSilverPrice();
  }

  // 캐시된 가격 로드
  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('silver_price');
      final cacheTime = prefs.getInt('silver_cache_time');
      
      if (cachedPrice != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 5분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 5 * 60 * 1000) {
          setState(() {
            _silverPrice = cachedPrice;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 캐시 로드 실패 시 무시
    }
  }

  // 가격 캐시 저장
  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('silver_price', price);
      await prefs.setInt('silver_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
  }

  Future<void> _fetchSilverPrice() async {
    // 여러 API를 순차적으로 시도
    final apis = [
      _tryMetalsAPI,
      _tryAlphaVantage,
      _tryYahooFinance,
    ];

    for (final api in apis) {
      try {
        final price = await api();
        if (price != null) {
          setState(() {
            _silverPrice = price;
            _isLoading = false;
          });
          await _cachePrice(price); // 가격 캐시 저장
          return;
        }
      } catch (e) {
        continue; // 다음 API 시도
      }
    }

    // 모든 API 실패 시
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  // Metals-API.com (무료 100회/월)
  Future<double?> _tryMetalsAPI() async {
    final response = await http.get(
      Uri.parse('https://metals-api.com/api/latest?access_key=YOUR_API_KEY&base=USD&symbols=XAG'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['rates']?['XAG']?.toDouble();
    }
    return null;
  }

  // Alpha Vantage (무료 5회/분, 500회/일)
  Future<double?> _tryAlphaVantage() async {
    final response = await http.get(
      Uri.parse('https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency=XAG&to_currency=USD&apikey=YOUR_API_KEY'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rate = data['Realtime Currency Exchange Rate']?['5. Exchange Rate'];
      return rate != null ? 1.0 / double.parse(rate) : null; // USD per XAG로 변환
    }
    return null;
  }

  // Yahoo Finance (무료, 제한 있음)
  Future<double?> _tryYahooFinance() async {
    final response = await http.get(
      Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/SI=F'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final price = data['chart']?['result']?[0]?['meta']?['regularMarketPrice'];
      return price?.toDouble();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const double krwPerUsd = 1383.66; // 환율
    const double ozToDon = 1 / 7.5599; // 1 oz ≒ 7.5599 돈

    double? krwPerDon;
    if (_silverPrice != null) {
      krwPerDon = _silverPrice! * krwPerUsd * ozToDon;
    }

    return Card(
      color: Colors.grey.shade800,
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
                          'Silver (XAG/USD)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '\$${_silverPrice!.toStringAsFixed(2)} / oz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (krwPerDon != null)
                          Text(
                            '약 ${krwPerDon.toStringAsFixed(0)}KRW / 돈',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}
