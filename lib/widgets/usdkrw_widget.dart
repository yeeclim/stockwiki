import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UsdKrwWidget extends StatefulWidget {
  const UsdKrwWidget({super.key});

  @override
  State<UsdKrwWidget> createState() => _UsdKrwWidgetState();
}

class _UsdKrwWidgetState extends State<UsdKrwWidget> {
  double? _usdKrw;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedRate();
    _fetchUsdKrw();
  }

  // 캐시된 환율 로드
  Future<void> _loadCachedRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRate = prefs.getDouble('usd_krw_rate');
      final cacheTime = prefs.getInt('usd_krw_cache_time');
      
      if (cachedRate != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 10분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 10 * 60 * 1000) {
          setState(() {
            _usdKrw = cachedRate;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 캐시 로드 실패 시 무시
    }
  }

  // 환율 캐시 저장
  Future<void> _cacheRate(double rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('usd_krw_rate', rate);
      await prefs.setInt('usd_krw_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
  }

  Future<void> _fetchUsdKrw() async {
    const apiKey = 'f1767aef0a23b6402850f3d9';
    final url = Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/latest/USD');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['conversion_rates']?['KRW'];

        if (rate != null && rate is num) {
          final rateValue = rate.toDouble();
          setState(() {
            _usdKrw = rateValue;
            _isLoading = false;
          });
          await _cacheRate(rateValue); // 환율 캐시 저장
        } else {
          throw Exception('API 응답에 KRW 없음');
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
              Colors.blueGrey.shade800,
              Colors.blueGrey.shade900,
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
                          const Text('USD/KRW', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            '₩${_usdKrw!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
