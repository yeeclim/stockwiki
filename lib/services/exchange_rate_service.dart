import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService {
  static const String _cacheKey = 'usd_krw_rate';
  static const String _timeKey = 'usd_krw_cache_time';
  static const int _cacheValidMinutes = 10;

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

      // open.er-api.com — 무료, API키 불필요, CORS 지원
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['rates']?['KRW'];
        if (rate != null) {
          final rateValue = (rate as num).toDouble();
          await prefs.setDouble(_cacheKey, rateValue);
          await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
          return rateValue;
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
