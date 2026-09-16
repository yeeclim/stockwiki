import 'package:supabase_flutter/supabase_flutter.dart';

/// 자동매매 설정.
///
/// kisAppKey / kisAppSecret / kisAccountNo / notifyKakaoRefreshToken 은
/// **저장할 때만** 값이 들어 있다. 서버는 이 값들을 AES-256-GCM 으로 암호화해
/// 보관하고 복호화해서 돌려주지 않으므로, load() 로 만든 객체에서는 항상 빈
/// 문자열이다. 저장 여부는 [hasStoredKeys] 로 판단한다.
class TradingConfig {
  final String brokerType;
  final String kisAppKey;
  final String kisAppSecret;
  final String kisAccountNo;
  final String kisAccountProdCode;
  final String notifyEmail;
  final String notifyKakaoRefreshToken;
  final int? dailyMaxBuy;
  final bool isActive;
  final DateTime? githubRegisteredAt;

  /// 서버에 키가 이미 저장돼 있는가. true 면 설정 화면은 마스킹만 보여주고,
  /// 사용자가 새로 입력한 항목만 서버로 보낸다(빈 칸은 기존 값 유지).
  final bool hasStoredKeys;

  /// 카카오 알림 토큰이 저장돼 있는가. 토큰 자체도 암호화돼 있어 값으로는
  /// 판별할 수 없으므로 notify_kakao_active 플래그를 쓴다.
  final bool hasStoredKakao;

  const TradingConfig({
    this.brokerType = 'kis',
    required this.kisAppKey,
    required this.kisAppSecret,
    required this.kisAccountNo,
    this.kisAccountProdCode = '01',
    this.notifyEmail = '',
    this.notifyKakaoRefreshToken = '',
    this.dailyMaxBuy,
    this.isActive = true,
    this.githubRegisteredAt,
    this.hasStoredKeys = false,
    this.hasStoredKakao = false,
  });

  factory TradingConfig.fromMap(Map<String, dynamic> m) => TradingConfig(
        brokerType: m['broker_type'] as String? ?? 'kis',
        // 서버가 돌려주는 건 암호문이다. 화면에 채울 수도, 쓸 수도 없으므로
        // 모델에 싣지 않는다 — 존재 여부만 hasStoredKeys 로 전달한다.
        kisAppKey: '',
        kisAppSecret: '',
        kisAccountNo: '',
        kisAccountProdCode: m['kis_account_prod_code'] as String? ?? '01',
        notifyEmail: m['notify_email'] as String? ?? '',
        notifyKakaoRefreshToken: '',
        dailyMaxBuy: m['daily_max_buy'] != null
            ? (m['daily_max_buy'] as num).toInt()
            : null,
        isActive: m['is_active'] as bool? ?? true,
        githubRegisteredAt: m['github_registered_at'] != null
            ? DateTime.parse(m['github_registered_at'] as String)
            : null,
        hasStoredKeys: ((m['kis_app_key'] as String?) ?? '').isNotEmpty,
        hasStoredKakao: m['notify_kakao_active'] as bool? ?? false,
      );

  /// 비어 있는 민감 필드는 아예 보내지 않는다. 서버(save-trading-config)는
  /// 누락된 필드를 "기존 값 유지"로 처리하므로, 사용자가 한도만 바꾸고 저장해도
  /// 저장된 키가 지워지지 않는다.
  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'broker_type': brokerType,
      'kis_account_prod_code': kisAccountProdCode,
      'notify_email': notifyEmail,
      'daily_max_buy': dailyMaxBuy,
    };
    if (kisAppKey.isNotEmpty) m['kis_app_key'] = kisAppKey;
    if (kisAppSecret.isNotEmpty) m['kis_app_secret'] = kisAppSecret;
    if (kisAccountNo.isNotEmpty) m['kis_account_no'] = kisAccountNo;
    if (notifyKakaoRefreshToken.isNotEmpty) {
      m['notify_kakao_refresh_token'] = notifyKakaoRefreshToken;
    }
    return m;
  }
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

  /// 설정 저장. Edge Function이 민감 필드를 암호화해 DB에 upsert 합니다.
  ///
  /// 반환값: {'ok': true, 'saved': true}
  static Future<Map<String, dynamic>> saveAndRegister(TradingConfig cfg) async {
    final session = _sb.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');

    final res = await _sb.functions.invoke(
      'save-trading-config',
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
        .update({'is_active': false}).eq('user_id', user.id);
  }
}
