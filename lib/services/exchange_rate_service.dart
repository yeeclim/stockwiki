import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class ExchangeRateService {
  static const String _cacheKey = 'usd_krw_rate';

  static Future<double?> getUsdToKrw() async {
    final cached = await CacheService.get(_cacheKey);
    if (cached is num) return cached.toDouble();

    try {
      // open.er-api.com — 무료, API키 불필요, CORS 지원
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final rate = json.decode(response.body)['rates']?['KRW'];
        if (rate != null) {
          final rateValue = (rate as num).toDouble();
          await CacheService.set(_cacheKey, rateValue,
              expiration: const Duration(minutes: 10));
          return rateValue;
        }
      }
    } catch (_) {}

    // 네트워크 실패 → 만료된 캐시라도 반환
    final stale = await CacheService.get(_cacheKey, allowExpired: true);
    return stale is num ? stale.toDouble() : null;
  }
}
