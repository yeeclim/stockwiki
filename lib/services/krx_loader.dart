import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class KrxLoader {
  // 캐시 처리를 위한 변수
  static List<String>? _cachedThemes;
  static final Map<String, List<Map<String, dynamic>>> _cachedThemeStocks = {};
  static final Map<String, DateTime> _themeStocksUpdatedAt = {};
  static DateTime? _lastThemeUpdate;

  // API 호출을 위한 베이스 URL 가져오기
  static String get _baseUrl {
    try {
      // Flutter Web 환경에서의 origin 가져오기
      final origin = Uri.base.origin;
      if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
        // 로컬 개발 환경에서는 고정된 개발 서버 URL 사용 가능 (필요시)
        return origin;
      }
      return origin;
    } catch (e) {
      return 'https://stockwiki.vercel.app'; // 폴백
    }
  }

  // 테마 목록 가져오기 (비동기)
  static Future<List<String>> getThemes() async {
    // 30분 캐시 적용
    if (_cachedThemes != null &&
        _lastThemeUpdate != null &&
        DateTime.now().difference(_lastThemeUpdate!).inMinutes < 30) {
      return _cachedThemes!;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/theme-recommendations?action=themes'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> themeList = data['data'];
          _cachedThemes = themeList.cast<String>();
          _lastThemeUpdate = DateTime.now();
          return _cachedThemes!;
        }
      }
      throw Exception('Failed to load themes: ${response.statusCode}');
    } catch (e) {
      debugPrint('테마 목록 로드 실패: $e');
      return _cachedThemes ?? []; // 실패 시 이전 캐시라도 반환
    }
  }

  // 관리 종목(스크리닝 후보)들의 개별 투자 포인트 조회.
  // 반환: { 종목코드: { points: [...], recommendation, price, changePercent, ma20, ma60, high52w } }
  static Future<Map<String, Map<String, dynamic>>> analyzeSymbols(
      List<String> codes) async {
    final valid = codes.where((c) => RegExp(r'^\d{6}$').hasMatch(c)).toList();
    if (valid.isEmpty) return {};
    try {
      final response = await http
          .get(Uri.parse(
              '$_baseUrl/api/theme-recommendations?action=analyze&symbols=${valid.join(',')}'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? []);
          return {
            for (final e in list.cast<Map<String, dynamic>>())
              e['symbol'] as String: e,
          };
        }
      }
    } catch (e) {
      debugPrint('관리 종목 분석 실패: $e');
    }
    return {};
  }

  // 특정 테마의 추천 종목 가져오기 (비동기)
  static Future<List<Map<String, dynamic>>> getThemeStocks(String theme) async {
    // 5분 캐시 적용 (종목 데이터는 더 자주 갱신)
    final updatedAt = _themeStocksUpdatedAt[theme];
    if (_cachedThemeStocks.containsKey(theme) &&
        updatedAt != null &&
        DateTime.now().difference(updatedAt).inMinutes < 5) {
      return _cachedThemeStocks[theme]!;
    }

    try {
      final encodedTheme = Uri.encodeComponent(theme);
      final response = await http
          .get(
            Uri.parse(
                '$_baseUrl/api/theme-recommendations?action=theme-recommendations&theme=$encodedTheme'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> stockList = data['data'];

          final processedStocks = stockList.map((s) {
            // API 응답 필드와 Dart 모델 필드 매핑
            return {
              'symbol': s['symbol'] ?? '',
              'name': s['name'] ?? '',
              'sector': s['sector'] ?? theme,
              'marketCap': s['marketCap'] ?? 0,
              'description': s['description'] ?? '',
              'reason': (s['reasons'] as List<dynamic>?)?.first?.toString() ??
                  s['recommendation']?.toString() ??
                  '관련 테마 수혜주',
              'score': s['totalScore'] ?? 0,
              'price': s['price'],
              'changePercent': s['changePercent'],
              'ma20': s['ma20'],
              'ma60': s['ma60'],
              'high52w': s['high52w'],
              'news': (s['news'] as List<dynamic>? ?? [])
                  .map((n) => {
                        'title': n['title'].toString(),
                        'url': n['url'].toString(),
                      })
                  .toList(),
            };
          }).toList();

          _cachedThemeStocks[theme] = processedStocks;
          _themeStocksUpdatedAt[theme] = DateTime.now();
          return processedStocks;
        }
      }
      throw Exception(
          'Failed to load stocks for theme $theme: ${response.statusCode}');
    } catch (e) {
      debugPrint('테마 종목 로드 실패 ($theme): $e');
      return _cachedThemeStocks[theme] ?? [];
    }
  }
}
