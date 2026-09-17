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

  bool get isUserAdded => source == 'user';
}

class ScreeningService {
  static final _sb = Supabase.instance.client;

  /// 전체 활성 후보 조회 (시스템 + 내가 추가한 것)
  static Future<List<ScreeningCandidate>> loadAll() async {
    final rows = await _sb
        .from('screening_candidates')
        .select()
        .eq('is_active', true)
        .order('sector')
        .order('stock_name');
    return rows.map((r) => ScreeningCandidate.fromMap(r)).toList();
  }

  /// 내가 추가한 종목만 조회
  static Future<List<ScreeningCandidate>> loadMine() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];
    final rows = await _sb
        .from('screening_candidates')
        .select()
        .eq('user_id', user.id)
        .eq('is_active', true)
        .order('sector')
        .order('stock_name');
    return rows.map((r) => ScreeningCandidate.fromMap(r)).toList();
  }

  /// 종목 추가
  static Future<void> add({
    required String stockCode,
    required String stockName,
    required String sector,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    await _sb.from('screening_candidates').insert({
      'stock_code': stockCode.trim(),
      'stock_name': stockName.trim(),
      'sector': sector.trim(),
      'source': 'user',
      'user_id': user.id,
      'is_active': true,
    });
  }

  /// 내 종목 삭제 (비활성화).
  ///
  /// RLS 로 막힌 행(남의 종목·시스템 종목)은 에러 없이 0행 수정으로 끝나므로,
  /// 실제로 바뀐 행이 없으면 예외를 던져 화면이 "삭제됐습니다"라고 거짓 표시하지 않게 한다.
  static Future<void> remove(String id) async {
    final updated = await _sb
        .from('screening_candidates')
        .update({'is_active': false})
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) {
      throw Exception('삭제 권한이 없거나 이미 삭제된 종목입니다.');
    }
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
