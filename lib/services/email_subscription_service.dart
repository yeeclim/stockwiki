import 'package:supabase_flutter/supabase_flutter.dart';

/// 스크리닝 메일 수신 동의 상태 (email_subscriptions 테이블).
///
/// 정보통신망법 제50조: 광고성 정보는 사전 동의, 21~08시 발송은 별도 동의가 필요하고
/// 동의는 2년마다 재확인한다. 동의 시각(consentedAt)은 DB 트리거가 기록하므로
/// 클라이언트는 수신 여부만 바꾼다.
class EmailSubscription {
  final bool emailOptIn;
  final bool nightOptIn;
  final DateTime? consentedAt;
  final DateTime? promptDismissedAt;

  const EmailSubscription({
    required this.emailOptIn,
    required this.nightOptIn,
    this.consentedAt,
    this.promptDismissedAt,
  });

  factory EmailSubscription.fromMap(Map<String, dynamic> m) =>
      EmailSubscription(
        emailOptIn: m['email_opt_in'] as bool? ?? false,
        nightOptIn: m['night_opt_in'] as bool? ?? false,
        consentedAt: DateTime.tryParse(m['consented_at'] as String? ?? ''),
        promptDismissedAt:
            DateTime.tryParse(m['prompt_dismissed_at'] as String? ?? ''),
      );

  /// 2년 만료 한 달 전부터 재확인을 요청한다 (발송은 2년이 지나면 서버에서 중단).
  bool get needsReconfirm =>
      emailOptIn &&
      consentedAt != null &&
      DateTime.now().difference(consentedAt!) > const Duration(days: 700);

  /// 동의 기간이 지나 현재 발송이 중단된 상태인가.
  bool get expired =>
      emailOptIn &&
      consentedAt != null &&
      DateTime.now().difference(consentedAt!) > const Duration(days: 730);
}

class EmailSubscriptionService {
  static final _sb = Supabase.instance.client;
  static const _columns =
      'email_opt_in, night_opt_in, consented_at, prompt_dismissed_at';

  /// 현재 사용자의 수신 설정. 로그인하지 않았거나 기록이 없으면 null.
  static Future<EmailSubscription?> load() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    final rows = await _sb
        .from('email_subscriptions')
        .select(_columns)
        .eq('user_id', user.id)
        .limit(1);
    return rows.isEmpty ? null : EmailSubscription.fromMap(rows.first);
  }

  /// 수신 여부 저장. 행이 없으면 만들고, 있으면 수정한다.
  /// (upsert 는 user_id 컬럼 UPDATE 권한이 필요해 쓰지 않는다)
  static Future<void> save({
    required bool emailOptIn,
    required bool nightOptIn,
  }) async {
    await _write({
      'email_opt_in': emailOptIn,
      'night_opt_in': emailOptIn && nightOptIn,
      'prompt_dismissed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 안내창에서 "나중에"를 누른 경우 — 다시 묻지 않도록 기록만 남긴다.
  static Future<void> dismissPrompt() async {
    await _write(
        {'prompt_dismissed_at': DateTime.now().toUtc().toIso8601String()});
  }

  /// 2년 재확인: 기존 동의를 유지한다.
  static Future<void> reconfirm() async {
    await _sb.rpc('reconfirm_email_consent');
  }

  static Future<void> _write(Map<String, dynamic> values) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final existing = await _sb
        .from('email_subscriptions')
        .select('user_id')
        .eq('user_id', user.id)
        .limit(1);
    if (existing.isEmpty) {
      await _sb
          .from('email_subscriptions')
          .insert({'user_id': user.id, ...values});
    } else {
      await _sb
          .from('email_subscriptions')
          .update(values)
          .eq('user_id', user.id);
    }
  }
}
