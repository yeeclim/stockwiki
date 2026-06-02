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
        id:        m['id'] as String,
        stockCode: m['stock_code'] as String,
        stockName: m['stock_name'] as String,
        sector:    m['sector'] as String,
        source:    m['source'] as String? ?? 'system',
        isActive:  m['is_active'] as bool? ?? true,
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
      'sector':     sector.trim(),
      'source':     'user',
      'user_id':    user.id,
      'is_active':  true,
    });
  }

  /// 내 종목 삭제 (비활성화)
  static Future<void> remove(String id) async {
    await _sb
        .from('screening_candidates')
        .update({'is_active': false})
        .eq('id', id);
  }
}
