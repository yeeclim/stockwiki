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

  String get _baseUrl {
    try {
      final origin = Uri.base.origin;
      if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
        return 'http://localhost:3000';
      }
      return origin;
    } catch (e) {
      return 'https://stockwiki.vercel.app';
    }
  }

  Future<void> _fetchUsdKrw() async {
    final url = Uri.parse('$_baseUrl/api/utils?type=commodity&symbol=KRW=X');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        
        if (result != null) {
          final meta = result['meta'];
          if (meta != null) {
            final rate = meta['regularMarketPrice'] ?? meta['previousClose'];
            if (rate != null) {
              final rateValue = rate.toDouble();
              setState(() {
                _usdKrw = rateValue;
                _isLoading = false;
              });
              await _cacheRate(rateValue); // 환율 캐시 저장
              return;
            }
          }
        }
        throw Exception('API 응답에 가격 정보 없음');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = Colors.indigo;

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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [accentColor.withOpacity(0.15), Colors.transparent]
                : [accentColor.withOpacity(0.1), Colors.transparent],
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
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.currency_exchange,
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'USD/KRW',
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)
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
                    '₩${_usdKrw!.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    '원',
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
