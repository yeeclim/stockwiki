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
          // App Key / Secret / 계좌번호 / 카카오 토큰은 서버에 암호화돼 있고
          // 복호화해서 돌려주지 않으므로 채우지 않는다. 저장돼 있다는 사실만
          // 힌트로 보여주고, 사용자가 새로 입력할 때만 교체된다.
          _prodCodeCtrl.text = cfg.kisAccountProdCode;
          _emailCtrl.text = cfg.notifyEmail;
          if (cfg.dailyMaxBuy != null) {
            _dailyMaxCtrl.text = cfg.dailyMaxBuy.toString();
          }
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
      await TradingConfigService.saveAndRegister(cfg);
      if (!mounted) return;

      _showResult(
        '✅ 저장 완료!\n키는 암호화되어 저장됐습니다. 다음 장부터 적용됩니다.',
        isError: false,
      );
      // 저장 직후에도 화면은 "등록됨" 상태여야 한다. 방금 보낸 평문을 그대로
      // 들고 있으면 안 되므로 민감 필드를 비운 사본으로 교체한다.
      setState(() {
        _existing = TradingConfig(
          brokerType: cfg.brokerType,
          kisAppKey: '',
          kisAppSecret: '',
          kisAccountNo: '',
          kisAccountProdCode: cfg.kisAccountProdCode,
          notifyEmail: cfg.notifyEmail,
          dailyMaxBuy: cfg.dailyMaxBuy,
          hasStoredKeys: true,
        );
        _appKeyCtrl.clear();
        _appSecretCtrl.clear();
        _accountCtrl.clear();
        _kakaoCtrl.clear();
      });
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
                          hint: _storedHint('P5...로 시작하는 키'),
                          icon: Icons.vpn_key_outlined,
                          validator: _requiredUnlessStored,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _appSecretCtrl,
                          label: 'App Secret',
                          hint: _storedHint('발급받은 App Secret'),
                          icon: Icons.lock_outline,
                          obscure: _obscureSecret,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureSecret
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscureSecret = !_obscureSecret),
                          ),
                          validator: _requiredUnlessStored,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _accountCtrl,
                          label: '계좌번호',
                          hint: _storedHint('8자리 숫자'),
                          icon: Icons.account_balance_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              // 저장된 값이 있으면 빈 칸 = 변경 안 함
                              return _keysStored ? null : '계좌번호를 입력하세요.';
                            }
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
                            if (v == null || v.trim().isEmpty) {
                              return '이메일을 입력하세요.';
                            }
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
                          !_kakaoLinked
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
                            label: Text(!_kakaoLinked
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

  /// 이미 저장된 키가 있으면 빈 칸은 "변경 안 함"이지 오류가 아니다.
  bool get _keysStored => _existing?.hasStoredKeys ?? false;

  /// 카카오 토큰도 암호화 저장이라 값으로 판별할 수 없다. 저장 플래그 또는
  /// 이번 화면에서 새로 입력/연동한 값이 있으면 연동된 것으로 본다.
  bool get _kakaoLinked =>
      _kakaoCtrl.text.trim().isNotEmpty || (_existing?.hasStoredKakao ?? false);

  String? _requiredUnlessStored(String? v) =>
      _keysStored && (v == null || v.trim().isEmpty) ? null : _required(v);

  String _storedHint(String label) =>
      _keysStored ? '•••••••• 저장됨 — 변경하려면 새로 입력' : label;

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
    return _banner(
      icon: Icons.check_circle_outline,
      color: Colors.green,
      bg: Colors.green.withValues(alpha: 0.1),
      text: '자동매매 활성 중  •  API 키는 암호화되어 저장됩니다.\n'
          '보안상 저장된 키는 다시 표시하지 않습니다. 바꿀 항목만 새로 입력하세요.',
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
