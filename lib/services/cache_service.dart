import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 데이터 캐시 저장
  static Future<void> set(String key, dynamic value, {Duration expiration = const Duration(minutes: 30)}) async {
    if (_prefs == null) await init();
    
    final data = {
      'value': value,
      'expiry': DateTime.now().add(expiration).millisecondsSinceEpoch,
    };
    
    await _prefs!.setString(key, json.encode(data));
    debugPrint('💾 [Cache] 저장: $key (만료: ${expiration.inMinutes}분 후)');
  }

  /// 데이터 캐시 조회
  static Future<dynamic> get(String key) async {
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

  /// 전체 캐시 삭제
  static Future<void> clear() async {
    if (_prefs == null) await init();
    await _prefs!.clear();
  }
}
