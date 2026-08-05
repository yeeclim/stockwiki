import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class UsSectorLoader {
  // 캐시 처리를 위한 변수 (원본 데이터가 하루 1번만 갱신되므로 KrxLoader의 테마 목록과
  // 동일하게 30분 캐시 — 단일 API 호출로 전체 섹터를 한 번에 받아오므로 통짜 캐시)
  static Map<String, List<Map<String, dynamic>>>? _cachedSectorData;
  static DateTime? _lastUpdate;

  // API 호출을 위한 베이스 URL 가져오기 (KrxLoader._baseUrl과 동일 로직)
  static String get _baseUrl {
    try {
      final origin = Uri.base.origin;
      if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
        return origin;
      }
      return origin;
    } catch (e) {
      return 'https://stockwiki.vercel.app'; // 폴백
    }
  }

  // 섹터별 추천 종목 전체 로드 (비동기, 단일 API 호출)
  static Future<Map<String, List<Map<String, dynamic>>>> loadAll() async {
    if (_cachedSectorData != null &&
        _lastUpdate != null &&
        DateTime.now().difference(_lastUpdate!).inMinutes < 30) {
      return _cachedSectorData!;
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/us-sector-recommend'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final Map<String, dynamic> raw = data['data'];
          final result = raw.map((sector, list) => MapEntry(
                sector,
                (list as List<dynamic>)
                    .map((s) => s as Map<String, dynamic>)
                    .toList(),
              ));
          _cachedSectorData = result;
          _lastUpdate = DateTime.now();
          return result;
        }
      }
      throw Exception('Failed to load sectors: ${response.statusCode}');
    } catch (e) {
      debugPrint('Sector 데이터 로드 실패: $e');
      return _cachedSectorData ?? {};
    }
  }
}
