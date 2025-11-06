import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoldWidget extends StatefulWidget {
  const GoldWidget({super.key});

  @override
  State<GoldWidget> createState() => _GoldWidgetState();
}

class _GoldWidgetState extends State<GoldWidget> {
  double? _goldPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchGoldPrice();
  }

  // 캐시된 가격 로드
  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('gold_price');
      final cacheTime = prefs.getInt('gold_cache_time');
      
      if (cachedPrice != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 5분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 5 * 60 * 1000) {
          setState(() {
            _goldPrice = cachedPrice;
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
      await prefs.setDouble('gold_price', price);
      await prefs.setInt('gold_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
  }

  Future<void> _fetchGoldPrice() async {
    try {
      final uri = Uri.parse(
        'https://api.twelvedata.com/price?symbol=XAU/USD&apikey=105c740ebca44e2ba687cfe806fa6b98',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['price'] != null) {
          final price = double.tryParse(data['price']);
          if (price != null) {
            setState(() {
              _goldPrice = price;
              _isLoading = false;
            });
            await _cachePrice(price); // 가격 캐시 저장
          } else {
            throw Exception('가격 데이터 형식 오류');
          }
        } else {
          throw Exception(data['message'] ?? '데이터 오류');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 고정 환율 사용 또는 외부에서 주입 가능
    const double krwPerUsd = 1383.66; // USD to KRW
    const double ozToDon = 1 / 7.5599; // 1 oz = 7.5599 돈

    double? krwPerDon;
    if (_goldPrice != null) {
      krwPerDon = _goldPrice! * krwPerUsd * ozToDon;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade600,
              Colors.amber.shade800,
            ],
          ),
        ),
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
                            'Gold (XAU/USD)',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            '\$${_goldPrice!.toStringAsFixed(2)} / oz',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (krwPerDon != null)
                            Text(
                              '약 ${krwPerDon.toStringAsFixed(0)} KRW / 돈',
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
      ),
    );
  }
}