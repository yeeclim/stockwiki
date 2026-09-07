import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 이 기기에서 로그인한 기록 1건.
class LoginRecord {
  final String provider; // 'google' | 'kakao' | 'email' | ...
  final DateTime at;

  LoginRecord(this.provider, this.at);

  Map<String, dynamic> toJson() =>
      {'provider': provider, 'at': at.toIso8601String()};

  factory LoginRecord.fromJson(Map<String, dynamic> j) => LoginRecord(
        j['provider'] as String? ?? 'unknown',
        DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );

  String get providerLabel {
    switch (provider) {
      case 'google':
        return 'Google';
      case 'kakao':
        return '카카오';
      case 'email':
        return '이메일';
      default:
        return provider;
    }
  }
}

/// 접속 기기(SharedPreferences)에만 저장되는 최근 로그인 기록.
/// 서버로 전송되지 않으며 최대 [_max]건까지 보관한다.
class LoginHistoryService {
  static const _key = 'login_history_v1';
  static const _max = 5;

  static Future<void> record(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _read(prefs);
      final now = DateTime.now();
      // OAuth 리다이렉트 등으로 짧은 시간에 같은 provider 이벤트가 중복될 수 있어 필터
      if (list.isNotEmpty &&
          list.first.provider == provider &&
          now.difference(list.first.at).inMinutes < 2) {
        return;
      }
      list.insert(0, LoginRecord(provider, now));
      final trimmed = list.take(_max).toList();
      await prefs.setString(
        _key,
        json.encode(trimmed.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<List<LoginRecord>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _read(prefs);
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static List<LoginRecord> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List;
      return decoded
          .map((e) => LoginRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
