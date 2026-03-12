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
  // Debug: Force redeploy v2.1

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
        // 10분 이내 캐시된 데이터가 있고, 'Fallback'이 포함되지 않은 경우만 사용
        if (now - cacheTime < 10 * 60 * 1000 && 
            (cachedDate == null || !cachedDate.contains('Fallback'))) {
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
    try {
      // 간단하고 안정적인 API 사용
      final result = await _trySimpleAPI();
      
      if (result != null && result['price'] != null && result['price']! > 0) {
        setState(() {
          _wtiPrice = result['price'];
          _date = result['date'];
          _isLoading = false;
        });
        await _cachePrice(result['price']!, result['date']);
        return;
      }
      
      // API 실패 시
      setState(() {
        _error = '데이터 로드 실패';
        _isLoading = false;
      });
      return;
    } catch (e) {
      // 모든 시도 실패 시
    }

    // 최종 실패 시
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  // 간단하고 안정적인 API
  Future<Map<String, dynamic>?> _trySimpleAPI() async {
    try {
      // Yahoo Finance API 사용 (더 안정적)
      final response = await http.get(
        Uri.parse('/api/utils?type=commodity&symbol=CL=F'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          if (meta != null) {
            final price = meta['regularMarketPrice'] ?? meta['previousClose'];
            if (price != null && price > 0) {
              return {
                'price': price.toDouble(),
                'date': 'Latest',
              };
            }
          }
        }
      }
    } catch (e) {
      // API 실패 시 무시
    }
    return null;
  }

  // Yahoo Finance - WTI Crude Oil Futures (CL=F)
  Future<Map<String, dynamic>?> _tryYahooFinance() async {
    try {
      final response = await http.get(
        Uri.parse('/api/utils?type=commodity&symbol=CL=F'),
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
      // Proxy 사용
      final response = await http.get(
        Uri.parse('/api/utils?type=commodity&symbol=BZ=F'),
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = Colors.teal;

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
                    Icons.opacity, // Oil droplet
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'WTI 유가',
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
                    _wtiPrice != null ? '\$${_wtiPrice!.toStringAsFixed(2)}' : 'N/A',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  if (_date != null)
                    Text(
                      _date!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
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
