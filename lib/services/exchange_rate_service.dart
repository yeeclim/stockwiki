import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService {
  static const String _cacheKey = 'usd_krw_rate';
  static const String _timeKey = 'usd_krw_cache_time';
  static const int _cacheValidMinutes = 10;

  static String get _baseUrl {
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

  // 환율 가져오기 (캐시 또는 API)
  static Future<double?> getUsdToKrw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRate = prefs.getDouble(_cacheKey);
      final cacheTime = prefs.getInt(_timeKey);

      if (cachedRate != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - cacheTime < _cacheValidMinutes * 60 * 1000) {
          return cachedRate;
        }
      }

      // API 호출
      final url = Uri.parse('$_baseUrl/api/utils?type=commodity&symbol=KRW=X');
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
              await prefs.setDouble(_cacheKey, rateValue);
              await prefs.setInt(
                  _timeKey, DateTime.now().millisecondsSinceEpoch);
              return rateValue;
            }
          }
        }
      }

      if (cachedRate != null) return cachedRate;
      return null;
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getDouble(_cacheKey);
      } catch (_) {
        return null;
      }
    }
  }
}
