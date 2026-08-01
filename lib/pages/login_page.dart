import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePw = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _errorMsg = msg);
  void _setLoading(bool v) => setState(() => _loading = v);

  // ── 이메일 로그인 / 회원가입 ────────────────────────────────────────────────
  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      _setError('이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      if (_isSignUp) {
        final res = await AuthService.signUp(email, pw);
        if (!mounted) return;
        if (res.user != null) {
          Navigator.of(context).pop();
        }
      } else {
        await AuthService.signInWithEmail(email, pw);
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _setError(_translateAuthError(e.message));
    } catch (e) {
      _setError('오류가 발생했습니다: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _signInGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      await AuthService.signInWithGoogle();
      // OAuth는 리디렉션 방식이라 여기서 바로 pop() 하지 않아도 됨
      // AuthProvider가 onAuthStateChange 이벤트를 받으면 Drawer가 갱신됨
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _setError('Google 로그인 실패: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  String _translateAuthError(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (msg.contains('Email not confirmed')) return '이메일 인증이 완료되지 않았습니다.';
    if (msg.contains('User already registered')) return '이미 가입된 이메일입니다.';
    if (msg.contains('Password should be at least')) {
      return '비밀번호는 최소 6자리 이상이어야 합니다.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isSignUp ? '회원가입' : '로그인',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // ── 로고 / 타이틀 ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Icon(Icons.auto_graph,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'StockWiki',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp ? '새 계정을 만들어 보세요.' : 'AI 자동매매를 이용하려면 로그인하세요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── 소셜 로그인 버튼 ──────────────────────────────────────────
            _SocialButton(
              label: 'Google로 계속하기',
              icon: _googleIcon(),
              onTap: _loading ? null : _signInGoogle,
              backgroundColor: isDark ? const Color(0xFF3C3C3C) : Colors.white,
              textColor: isDark ? Colors.white : const Color(0xFF1F1F1F),
              borderColor:
                  isDark ? Colors.transparent : const Color(0xFFDADCE0),
            ),

            const SizedBox(height: 28),

            // ── 구분선 ──────────────────────────────────────────────────────
            Row(children: [
              Expanded(child: Divider(color: theme.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('또는 이메일로',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(child: Divider(color: theme.dividerColor)),
            ]),

            const SizedBox(height: 20),

            // ── 이메일 폼 ──────────────────────────────────────────────────
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDec(context, '이메일', Icons.email_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwCtrl,
              obscureText: _obscurePw,
              onSubmitted: (_) => _submitEmail(),
              decoration:
                  _inputDec(context, '비밀번호', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePw ? Icons.visibility_off : Icons.visibility,
                      color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => setState(() => _obscurePw = !_obscurePw),
                ),
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(_errorMsg!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ],

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loading ? null : _submitEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isSignUp ? '회원가입' : '로그인',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),

            const SizedBox(height: 16),

            // ── 로그인 ↔ 회원가입 전환 ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp ? '이미 계정이 있으신가요?' : '아직 계정이 없으신가요?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMsg = null;
                    });
                  },
                  child: Text(_isSignUp ? '로그인' : '회원가입',
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(BuildContext ctx, String label, IconData icon) {
    final theme = Theme.of(ctx);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
    );
  }

  Widget _googleIcon() {
    return const Text('G',
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue));
  }
}

// ── 소셜 버튼 공용 위젯 ────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, child: icon),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
