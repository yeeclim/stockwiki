import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// gold/silver/wti/btc 위젯들이 각자 복붙해 쓰던 "SharedPreferences에 마지막
/// 시세를 캐싱했다가 TTL 안이면 재사용" 로직을 공통화한 mixin.
mixin PriceCacheMixin<T extends StatefulWidget> on State<T> {
  Future<double?> loadCachedPrice(String cacheKey, Duration maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('${cacheKey}_price');
      final cacheTime = prefs.getInt('${cacheKey}_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (age < maxAge.inMilliseconds) {
          return cachedPrice;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> cachePrice(String cacheKey, double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${cacheKey}_price', price);
      await prefs.setInt(
          '${cacheKey}_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
