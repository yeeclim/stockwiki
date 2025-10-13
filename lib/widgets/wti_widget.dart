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
    const apiKey = '4X0kMGDGQo7wdJ0BAtVJ3PygI15g8GdiVQsCpeGt';
    const url = 'https://api.eia.gov/v2/seriesid/PET.RWTC.D?api_key=$apiKey';

    try {
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latest = data['response']['data'][0];
        final price = latest['value']?.toDouble();
        final date = latest['period'];

        setState(() {
          _wtiPrice = price;
          _date = date;
          _isLoading = false;
        });
        
        if (price != null) {
          await _cachePrice(price, date);
        }
      } else {
        throw Exception('응답 코드: ${response.statusCode}');
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
