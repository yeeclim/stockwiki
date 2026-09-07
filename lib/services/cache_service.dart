import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 데이터 캐시 저장
  static Future<void> set(String key, dynamic value,
      {Duration expiration = const Duration(minutes: 30)}) async {
    if (_prefs == null) await init();

    final data = {
      'value': value,
      'expiry': DateTime.now().add(expiration).millisecondsSinceEpoch,
    };

    await _prefs!.setString(key, json.encode(data));
    debugPrint('💾 [Cache] 저장: $key (만료: ${expiration.inMinutes}분 후)');
  }

  /// 데이터 캐시 조회.
  /// [allowExpired] 가 true면 만료된 값도 반환한다(네트워크 실패 시 stale 폴백용).
  static Future<dynamic> get(String key, {bool allowExpired = false}) async {
    if (_prefs == null) await init();

    if (!_prefs!.containsKey(key)) {
      return null;
    }

    try {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) return null;

      final data = json.decode(jsonString);
      final expiry = data['expiry'] as int;

      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        if (allowExpired) {
          debugPrint('⌛ [Cache] 만료(stale 반환): $key');
          return data['value'];
        }
        debugPrint('🗑️ [Cache] 만료됨: $key');
        await _prefs!.remove(key);
        return null; // 만료됨
      }

      debugPrint('⚡ [Cache] 히트: $key');
      return data['value'];
    } catch (e) {
      debugPrint('⚠️ [Cache] 오류: $e');
      await _prefs!.remove(key);
      return null;
    }
  }

  /// 캐시 삭제
  static Future<void> remove(String key) async {
    if (_prefs == null) await init();
    await _prefs!.remove(key);
  }

  /// 캐시 항목만 삭제 (value+expiry JSON 구조인 키만 제거, 앱 설정 보존)
  static Future<void> clear() async {
    if (_prefs == null) await init();
    final keys = _prefs!.getKeys().toList();
    for (final key in keys) {
      try {
        final raw = _prefs!.getString(key);
        if (raw == null) continue;
        final decoded = json.decode(raw);
        if (decoded is Map &&
            decoded.containsKey('expiry') &&
            decoded.containsKey('value')) {
          await _prefs!.remove(key);
        }
      } catch (_) {}
    }
  }
}
