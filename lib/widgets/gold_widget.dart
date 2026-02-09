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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Subtle gradient for modern feel without being overwhelming
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.amber.withOpacity(0.15), Colors.transparent]
                : [Colors.amber.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.monetization_on_outlined,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gold',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (_isLoading)
               Center(
                  child: SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)
                  )
               )
            else if (_error != null)
              Center(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                )
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${_goldPrice!.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber, 
                    ),
                  ),
                  if (krwPerDon != null)
                    Text(
                      '약 ${krwPerDon.toStringAsFixed(0)}원 / 돈',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}