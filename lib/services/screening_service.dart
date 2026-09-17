import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ScreeningCandidate {
  final String id;
  final String stockCode;
  final String stockName;
  final String sector;
  final String source;
  final bool isActive;

  const ScreeningCandidate({
    required this.id,
    required this.stockCode,
    required this.stockName,
    required this.sector,
    required this.source,
    this.isActive = true,
  });

  factory ScreeningCandidate.fromMap(Map<String, dynamic> m) =>
      ScreeningCandidate(
        id: m['id'] as String,
        stockCode: m['stock_code'] as String,
        stockName: m['stock_name'] as String,
        sector: m['sector'] as String,
        source: m['source'] as String? ?? 'system',
        isActive: m['is_active'] as bool? ?? true,
      );

  /// 관리자가 수동으로 추가한 종목 (광역 스캔이 자동으로 끄지 않는다)
  bool get isManual => source == 'admin';
}

class ScreeningService {
  static final _sb = Supabase.instance.client;

  /// 전체 활성 후보 조회 (광역 스캔 선정 + 관리자 수동 추가)
  static Future<List<ScreeningCandidate>> loadAll() async {
    final rows = await _sb
        .from('screening_candidates')
        .select()
        .eq('is_active', true)
        .order('sector')
        .order('stock_name');
    return rows.map((r) => ScreeningCandidate.fromMap(r)).toList();
  }

  // ── 관리자 전용: 종목 제외/복원 ─────────────────────────────────────────────
  // 서버(api/utils?type=admin-candidate)가 관리자 확인 후 처리한다. 제외된 종목은
  // 광역 스캔·스크리닝 메일·추천 목록·자동매매에서 모두 빠지고, 다음 날 스캔이 되살리지 않는다.

  static Uri _adminUri() {
    final origin = Uri.base.scheme.startsWith('http')
        ? Uri.base.origin
        : 'https://stockwiki.vercel.app';
    return Uri.parse('$origin/api/utils?type=admin-candidate');
  }

  static Map<String, String> _adminHeaders() {
    final token = _sb.auth.currentSession?.accessToken;
    if (token == null) throw Exception('로그인이 필요합니다.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _checked(http.Response res) {
    final Object? body;
    try {
      body = jsonDecode(res.body);
    } on FormatException {
      // Vercel 오류 페이지(HTML) 등 JSON 이 아닌 응답
      throw Exception('서버 응답 오류 (${res.statusCode})');
    }
    if (res.statusCode != 200 || body is! Map || body['success'] != true) {
      throw Exception(
          (body is Map ? body['error'] : null) ?? '요청 실패 (${res.statusCode})');
    }
    return Map<String, dynamic>.from(body);
  }

  static Future<void> _adminAction(String stockCode, String action) async {
    final res = await http
        .post(_adminUri(),
            headers: _adminHeaders(),
            body: jsonEncode({'stockCode': stockCode, 'action': action}))
        .timeout(const Duration(seconds: 15));
    _checked(res);
  }

  /// 관리자 수동 추가. 스크리닝 종목 관리는 관리자 전용이라 클라이언트가 DB 에 직접
  /// 쓰지 않고 서버(관리자 확인 후 service_role)가 넣는다.
  static Future<void> addAsAdmin({
    required String stockCode,
    required String stockName,
    required String sector,
  }) async {
    final res = await http
        .post(_adminUri(),
            headers: _adminHeaders(),
            body: jsonEncode({
              'action': 'add',
              'stockCode': stockCode,
              'stockName': stockName,
              'sector': sector,
            }))
        .timeout(const Duration(seconds: 15));
    _checked(res);
  }

  static Future<void> excludeAsAdmin(String stockCode) =>
      _adminAction(stockCode, 'exclude');

  static Future<void> restoreAsAdmin(String stockCode) =>
      _adminAction(stockCode, 'restore');

  /// 관리자가 제외한 종목 목록 (stock_code, stock_name, sector)
  static Future<List<Map<String, dynamic>>> loadExcluded() async {
    final res = await http
        .get(_adminUri(), headers: _adminHeaders())
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(_checked(res)['data'] as List);
  }
}
