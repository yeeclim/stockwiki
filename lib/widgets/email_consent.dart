import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/email_subscription_service.dart';

const _emailConsentText = '매일 스크리닝 결과와 시장 브리핑(광고성 정보 포함)을 이메일로 받습니다.';
const _nightConsentText =
    '스크리닝 메일은 06:30과 15:00에 발송됩니다. 동의하지 않으면 15:00 발송분만 받습니다. '
    '카카오톡 알림의 야간 발송에도 적용됩니다.';
const _consentNotice = '모두 선택 사항이며, 마이페이지나 메일 하단 수신거부 링크로 언제든 철회할 수 있습니다. '
    '동의는 2년마다 다시 확인합니다.';

/// 로그인 후 한 번: 동의 기록이 없는 사용자에게 수신 동의를 묻는다.
/// 동의가 2년 만료에 가까우면 재확인을 요청한다.
/// 같은 앱 실행 중에는 한 번만 확인한다.
bool _checkedThisSession = false;

Future<void> maybePromptEmailConsent(BuildContext context) async {
  if (_checkedThisSession) return;
  if (Supabase.instance.client.auth.currentUser == null) return;
  _checkedThisSession = true;

  EmailSubscription? sub;
  try {
    sub = await EmailSubscriptionService.load();
  } catch (_) {
    _checkedThisSession = false; // 네트워크 오류면 다음 기회에 다시 확인
    return;
  }
  if (!context.mounted) return;

  if (sub != null && sub.needsReconfirm) {
    await _showReconfirmDialog(context, sub);
  } else if (sub == null ||
      (!sub.emailOptIn && sub.promptDismissedAt == null)) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConsentDialog(),
    );
  }
}

Future<void> _showReconfirmDialog(
    BuildContext context, EmailSubscription sub) async {
  final keep = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('메일 수신 동의 확인'),
      content: Text(sub.expired
          ? '수신 동의 후 2년이 지나 스크리닝 메일 발송이 중단되었습니다.\n계속 받으시겠어요?'
          : '스크리닝 메일 수신에 동의하신 지 2년이 다 되어 갑니다.\n계속 받으시겠어요?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('그만 받기')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속 받기')),
      ],
    ),
  );
  try {
    if (keep == true) {
      await EmailSubscriptionService.reconfirm();
    } else {
      await EmailSubscriptionService.save(emailOptIn: false, nightOptIn: false);
    }
  } catch (_) {}
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _email = false;
  bool _night = false;
  bool _saving = false;

  Future<void> _submit({required bool later}) async {
    setState(() => _saving = true);
    try {
      if (later) {
        await EmailSubscriptionService.dismissPrompt();
      } else {
        await EmailSubscriptionService.save(
            emailOptIn: _email, nightOptIn: _night);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('스크리닝 메일 받기'),
      content: SingleChildScrollView(
        child: EmailConsentFields(
          email: _email,
          night: _night,
          onChanged: (email, night) => setState(() {
            _email = email;
            _night = night;
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => _submit(later: true),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _submit(later: false),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 수신 동의 체크 항목 (안내창·마이페이지 공용). 야간 동의는 메일 수신 동의가 있을 때만 켤 수 있다.
class EmailConsentFields extends StatelessWidget {
  final bool email;
  final bool night;
  final void Function(bool email, bool night) onChanged;

  const EmailConsentFields({
    super.key,
    required this.email,
    required this.night,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: email,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('[선택] 스크리닝 메일 수신 동의'),
          subtitle: Text(_emailConsentText, style: muted),
          onChanged: (v) => onChanged(v ?? false, (v ?? false) && night),
        ),
        CheckboxListTile(
          value: email && night,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('[선택] 야간(21시~08시) 수신 동의'),
          subtitle: Text(_nightConsentText, style: muted),
          onChanged: email ? (v) => onChanged(email, v ?? false) : null,
        ),
        const SizedBox(height: 8),
        Text(_consentNotice, style: muted),
      ],
    );
  }
}

/// 마이페이지용 수신 설정 카드 — 바꾸는 즉시 저장한다.
class EmailSubscriptionCard extends StatefulWidget {
  const EmailSubscriptionCard({super.key});

  @override
  State<EmailSubscriptionCard> createState() => _EmailSubscriptionCardState();
}

class _EmailSubscriptionCardState extends State<EmailSubscriptionCard> {
  EmailSubscription? _sub;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sub = await EmailSubscriptionService.load();
      if (mounted) setState(() => _sub = sub);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(bool email, bool night) async {
    setState(() => _saving = true);
    try {
      await EmailSubscriptionService.save(emailOptIn: email, nightOptIn: night);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(email ? '수신 설정이 저장되었습니다.' : '스크리닝 메일 수신을 해지했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = _sub;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('스크리닝 메일 수신 설정',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (sub?.consentedAt != null && sub!.emailOptIn) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub.expired
                        ? '동의 후 2년이 지나 발송이 중단되었습니다. 아래에서 다시 동의해 주세요.'
                        : '동의일 ${sub.consentedAt!.toLocal().toString().substring(0, 10)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: sub.expired
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (sub != null && sub.expired) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await EmailSubscriptionService.reconfirm();
                              await _load();
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    child: const Text('계속 받기 (동의 재확인)'),
                  ),
                ],
                AbsorbPointer(
                  absorbing: _saving,
                  child: EmailConsentFields(
                    email: sub?.emailOptIn ?? false,
                    night: sub?.nightOptIn ?? false,
                    onChanged: _change,
                  ),
                ),
              ],
            ),
    );
  }
}
