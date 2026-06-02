import 'package:supabase_flutter/supabase_flutter.dart';

class TradingConfig {
  final String brokerType;
  final String kisAppKey;
  final String kisAppSecret;
  final String kisAccountNo;
  final String kisAccountProdCode;
  final String notifyEmail;
  final bool isActive;
  final DateTime? githubRegisteredAt;

  const TradingConfig({
    this.brokerType = 'kis',
    required this.kisAppKey,
    required this.kisAppSecret,
    required this.kisAccountNo,
    this.kisAccountProdCode = '01',
    this.notifyEmail = '',
    this.isActive = true,
    this.githubRegisteredAt,
  });

  factory TradingConfig.fromMap(Map<String, dynamic> m) => TradingConfig(
        brokerType:          m['broker_type'] as String? ?? 'kis',
        kisAppKey:           m['kis_app_key'] as String,
        kisAppSecret:        m['kis_app_secret'] as String,
        kisAccountNo:        m['kis_account_no'] as String,
        kisAccountProdCode:  m['kis_account_prod_code'] as String? ?? '01',
        notifyEmail:         m['notify_email'] as String? ?? '',
        isActive:            m['is_active'] as bool? ?? true,
        githubRegisteredAt:  m['github_registered_at'] != null
            ? DateTime.parse(m['github_registered_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'broker_type':           brokerType,
        'kis_app_key':           kisAppKey,
        'kis_app_secret':        kisAppSecret,
        'kis_account_no':        kisAccountNo,
        'kis_account_prod_code': kisAccountProdCode,
        'notify_email':          notifyEmail,
      };
}

class TradingConfigService {
  static final _sb = Supabase.instance.client;

  /// 현재 로그인 사용자의 설정 조회 (없으면 null)
  static Future<TradingConfig?> load() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;

    final rows = await _sb
        .from('trading_configs')
        .select()
        .eq('user_id', user.id)
        .limit(1);

    if (rows.isEmpty) return null;
    return TradingConfig.fromMap(rows.first);
  }

  /// 설정 저장 + GitHub Actions 시크릿 자동 등록
  ///
  /// Edge Function이 DB upsert + GitHub API 등록을 모두 처리합니다.
  /// 반환값: {'ok': true, 'github': true/false}
  static Future<Map<String, dynamic>> saveAndRegister(TradingConfig cfg) async {
    final session = _sb.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');

    final res = await _sb.functions.invoke(
      'register-to-github',
      body: cfg.toMap(),
    );

    if (res.status >= 400) {
      final msg = (res.data as Map?)?['error'] ?? '알 수 없는 오류';
      throw Exception(msg);
    }

    return (res.data as Map<String, dynamic>?) ?? {'ok': true};
  }

  /// 자동매매 비활성화
  static Future<void> deactivate() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    await _sb
        .from('trading_configs')
        .update({'is_active': false})
        .eq('user_id', user.id);
  }
}
