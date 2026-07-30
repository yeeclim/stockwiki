import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/trading_config_service.dart';
import 'kis_guide_page.dart';
import 'kakao_guide_page.dart';

const _kakaoRestApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');

class TradingSetupPage extends StatefulWidget {
  final String initialBroker;
  const TradingSetupPage({super.key, this.initialBroker = 'kis'});

  @override
  State<TradingSetupPage> createState() => _TradingSetupPageState();
}

class _BrokerOption {
  final String id;
  final String name;
  final Color color;
  const _BrokerOption(this.id, this.name, this.color);
}

class _TradingSetupPageState extends State<TradingSetupPage> {
  static const _brokers = [
    _BrokerOption('kis', '한국투자증권', Color(0xFF0066CC)),
    _BrokerOption('kiwoom', '키움증권', Color(0xFFE8001C)),
    _BrokerOption('nh', 'NH 나무', Color(0xFF00A651)),
    _BrokerOption('samsung', '삼성증권', Color(0xFF1428A0)),
  ];

  final _formKey = GlobalKey<FormState>();
  final _appKeyCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _prodCodeCtrl = TextEditingController(text: '01');
  final _emailCtrl = TextEditingController();
  final _kakaoCtrl = TextEditingController();
  final _dailyMaxCtrl = TextEditingController();

  late String _selectedBroker;
  bool _loading = true;
  bool _saving = false;
  bool _obscureSecret = true;
  TradingConfig? _existing;

  @override
  void initState() {
    super.initState();
    _selectedBroker = widget.initialBroker;
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final cfg = await TradingConfigService.load();
      if (!mounted) return;
      setState(() {
        _existing = cfg;
        _loading = false;
        if (cfg != null) {
          _selectedBroker = cfg.brokerType;
          _appKeyCtrl.text = cfg.kisAppKey;
          _appSecretCtrl.text = cfg.kisAppSecret;
          _accountCtrl.text = cfg.kisAccountNo;
          _prodCodeCtrl.text = cfg.kisAccountProdCode;
          _emailCtrl.text = cfg.notifyEmail;
          _kakaoCtrl.text = cfg.notifyKakaoRefreshToken;
          if (cfg.dailyMaxBuy != null)
            _dailyMaxCtrl.text = cfg.dailyMaxBuy.toString();
        } else {
          final email = context.read<AuthProvider>().currentUser?.email ?? '';
          _emailCtrl.text = email;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        final email = context.read<AuthProvider>().currentUser?.email ?? '';
        _emailCtrl.text = email;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final cfg = TradingConfig(
      brokerType: _selectedBroker,
      kisAppKey: _appKeyCtrl.text.trim(),
      kisAppSecret: _appSecretCtrl.text.trim(),
      kisAccountNo: _accountCtrl.text.trim(),
      kisAccountProdCode: _prodCodeCtrl.text.trim(),
      notifyEmail: _emailCtrl.text.trim(),
      notifyKakaoRefreshToken: _kakaoCtrl.text.trim(),
      dailyMaxBuy: int.tryParse(_dailyMaxCtrl.text.trim()),
    );

    try {
      final res = await TradingConfigService.saveAndRegister(cfg);
      if (!mounted) return;

      final githubOk = res['github'] == true;
      _showResult(
        githubOk
            ? '✅ 저장 완료!\nGitHub Actions 시크릿에 자동 등록됐습니다.'
            : '✅ 저장 완료!\n(GitHub 등록은 관리자에게 문의하세요)',
        isError: false,
      );
      setState(() => _existing = cfg);
    } catch (e) {
      if (!mounted) return;
      _showResult('오류: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('자동매매 비활성화'),
        content: const Text('자동매매를 중단하시겠습니까?\n등록된 키는 그대로 유지됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('비활성화',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TradingConfigService.deactivate();
    if (!mounted) return;
    setState(() => _existing = null);
    _showResult('자동매매가 비활성화됐습니다.', isError: false);
  }

  void _showResult(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _appKeyCtrl.dispose();
    _appSecretCtrl.dispose();
    _accountCtrl.dispose();
    _prodCodeCtrl.dispose();
    _emailCtrl.dispose();
    _kakaoCtrl.dispose();
    _dailyMaxCtrl.dispose();
    super.dispose();
  }

  /// 카카오 로그인 페이지로 이동(같은 탭) — 돌아오면 main.dart의
  /// _completeKakaoLink()가 인가 코드를 받아 서버에서 토큰 교환을 처리한다.
  Future<void> _connectKakao() async {
    if (_kakaoRestApiKey.isEmpty) {
      _showResult('카카오 연동 설정이 아직 배포되지 않았습니다.', isError: true);
      return;
    }
    final state = List.generate(24, (_) => Random.secure().nextInt(36))
        .map((n) => n.toRadixString(36))
        .join();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kakao_link_state', state);

    final uri = Uri.https('kauth.kakao.com', '/oauth/authorize', {
      'client_id': _kakaoRestApiKey,
      'redirect_uri': 'https://stockwiki.vercel.app',
      'response_type': 'code',
      'scope': 'talk_message openid',
      'state': state,
    });
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'API 키 등록',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KisGuidePage()),
            ),
            icon: Icon(Icons.help_outline,
                size: 18, color: theme.colorScheme.primary),
            label: Text('발급 가이드',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 상태 배너 ──────────────────────────────────────────────
                  _StatusBanner(existing: _existing, theme: theme),
                  const SizedBox(height: 24),

                  // ── 증권사 선택 ────────────────────────────────────────────
                  Text('증권사 선택',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _brokers.map((b) {
                      final selected = _selectedBroker == b.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBroker = b.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                selected ? b.color : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? b.color : theme.dividerColor,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            b.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── 입력 폼 ────────────────────────────────────────────────
                  Text('API 키 정보',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '선택한 증권사 개발자 사이트에서 발급받은 키를 입력하세요.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _Field(
                          controller: _appKeyCtrl,
                          label: 'App Key',
                          hint: 'P5...로 시작하는 키',
                          icon: Icons.vpn_key_outlined,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _appSecretCtrl,
                          label: 'App Secret',
                          hint: '발급받은 App Secret',
                          icon: Icons.lock_outline,
                          obscure: _obscureSecret,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureSecret
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscureSecret = !_obscureSecret),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _accountCtrl,
                          label: '계좌번호',
                          hint: '8자리 숫자',
                          icon: Icons.account_balance_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return '계좌번호를 입력하세요.';
                            if (v.trim().length != 8) return '계좌번호는 8자리입니다.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _prodCodeCtrl,
                          label: '상품코드',
                          hint: '보통 01',
                          icon: Icons.tag,
                          validator: _required,
                        ),
                        const SizedBox(height: 20),

                        Divider(color: theme.dividerColor),
                        const SizedBox(height: 12),

                        Text('이메일 알림',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _emailCtrl,
                          label: '알림 받을 이메일',
                          hint: 'example@gmail.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return '이메일을 입력하세요.';
                            if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('카카오톡 알림 (선택)',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _kakaoCtrl.text.trim().isEmpty
                              ? '카카오 로그인 한 번으로 스크리닝 결과를 카카오톡으로 받아보세요.'
                              : '✅ 카카오톡 알림이 연동되어 있습니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _existing == null ? null : _connectKakao,
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(_kakaoCtrl.text.trim().isEmpty
                                ? '카카오 알림 연동하기'
                                : '카카오 알림 다시 연동하기'),
                          ),
                        ),
                        if (_existing == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '증권사 정보를 먼저 저장해야 연동할 수 있어요.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text('고급: 리프레시 토큰 직접 입력',
                              style: theme.textTheme.bodySmall),
                          children: [
                            _Field(
                              controller: _kakaoCtrl,
                              label: '카카오 리프레시 토큰',
                              hint: '카카오 앱에서 발급된 리프레시 토큰',
                              icon: Icons.chat_bubble_outline,
                              validator: (v) => null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const KakaoGuidePage()),
                                ),
                                icon: Icon(Icons.help_outline,
                                    size: 16, color: theme.colorScheme.primary),
                                label: Text('카카오 발급 가이드 보기',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text('일일 최대 매수금액 (원, 선택)',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _dailyMaxCtrl,
                          label: '일일 최대 매수금액',
                          hint: '예: 500000',
                          icon: Icons.monetization_on_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return '유효한 금액을 입력하세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // ── 저장 버튼 ──────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(_saving ? '등록 중…' : 'GitHub에 자동 등록'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        // ── 비활성화 버튼 (기존 설정 있을 때만) ───────────────
                        if (_existing != null && _existing!.isActive) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _deactivate,
                              icon: const Icon(Icons.pause_circle_outline),
                              label: const Text('자동매매 일시 중지'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side:
                                    BorderSide(color: theme.colorScheme.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── 주의 문구 ──────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: theme.colorScheme.error, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '입력된 키는 암호화되어 저장되며, 자동매매 실행에만 사용됩니다.\n'
                                  '모든 투자 결과에 대한 책임은 본인에게 있습니다.',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 항목입니다.' : null;
}

// ── 하위 위젯 ─────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final TradingConfig? existing;
  final ThemeData theme;

  const _StatusBanner({required this.existing, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (existing == null) {
      return _banner(
        icon: Icons.info_outline,
        color: theme.colorScheme.primary,
        bg: theme.colorScheme.primary.withValues(alpha: 0.1),
        text: '아직 자동매매 설정이 없습니다.\n아래에 KIS API 키를 입력하고 등록하세요.',
      );
    }
    if (!existing!.isActive) {
      return _banner(
        icon: Icons.pause_circle_outline,
        color: Colors.orange,
        bg: Colors.orange.withValues(alpha: 0.1),
        text: '자동매매가 일시 중지 상태입니다.\n키를 재등록하면 다시 활성화됩니다.',
      );
    }
    final registered = existing!.githubRegisteredAt;
    final dateStr = registered != null
        ? '${registered.year}-${registered.month.toString().padLeft(2, '0')}-${registered.day.toString().padLeft(2, '0')}'
        : '알 수 없음';
    return _banner(
      icon: Icons.check_circle_outline,
      color: Colors.green,
      bg: Colors.green.withValues(alpha: 0.1),
      text: '자동매매 활성 중  •  GitHub 등록일: $dateStr\n수정 후 다시 등록하면 즉시 반영됩니다.',
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
