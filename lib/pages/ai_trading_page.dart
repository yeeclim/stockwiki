import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'trading_setup_page.dart';
import 'kis_guide_page.dart';
import 'screening_manage_page.dart';
import 'admin_screening_page.dart';

class AiTradingPage extends StatelessWidget {
  const AiTradingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!authProvider.isLoggedIn) {
      // 로그인하지 않은 경우 → 로그인 유도
      return Scaffold(
        appBar: _appBar(context, theme),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('로그인이 필요한 서비스입니다.', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const LoginPage())),
                child: const Text('로그인 / 회원가입'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context, theme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 유저 정보 카드 ─────────────────────────────────────────────
            _UserCard(authProvider: authProvider, theme: theme),
            const SizedBox(height: 24),

            // ── 자동매매 개요 ─────────────────────────────────────────────
            _sectionTitle(context, '📊 자동매매 전략 개요'),
            const SizedBox(height: 12),
            _InfoCard(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '복합 조건 점수제 (11점 만점, 6점 이상 매수)'),
                  _bullet(theme, '현재가 < 60일 이평선 → 필수 조건 (+2점)'),
                  _bullet(theme, '골든크로스(MA5↑MA20) → +2점 / MA5>MA20 → +1점'),
                  _bullet(theme, '저PER(< 15) → +1점  |  저PBR(< 1.5) → +1점'),
                  _bullet(theme, '거래량 ≥ 10만주 → +1점'),
                  _bullet(theme, '부채비율 < 200% → +1점  |  유동비율 > 100% → +1점'),
                  _bullet(theme, '현금비율 > 20% → +1점  |  이자보상배율 ≥ 400% → +1점'),
                  const SizedBox(height: 8),
                  _bullet(theme, '-5% 손절 → 예수금 5% 추가 매수'),
                  _bullet(theme, '-10% 손절 → 예수금 10% 추가 매수'),
                  _bullet(theme, '📌 매도는 사용자가 직접 판단 (자동 매도 미적용)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── API 키 등록 버튼 ───────────────────────────────────────────
            _sectionTitle(context, '🔑 나만의 자동매매 시작하기'),
            const SizedBox(height: 12),
            _StepCard(
              theme: theme,
              stepNumber: '1',
              title: '한국투자증권 Open API 신청',
              content: 'developers.koreainvestment.com 에서 앱 등록 후\n'
                  'App Key · App Secret 을 발급받으세요.\n'
                  '(실전 계좌 이용 신청 필수)',
            ),
            const SizedBox(height: 12),
            _StepCard(
              theme: theme,
              stepNumber: '2',
              title: 'StockWiki에 API 키 등록',
              content: '아래 버튼을 눌러 발급받은 키를 입력하면\n'
                  'GitHub Actions에 자동으로 등록되고\n'
                  '평일 장중 5분마다 자동매매가 실행됩니다.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TradingSetupPage()),
                ),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('API 키 등록 / 수정'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KisGuidePage()),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('API 키발급 방법'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ScreeningManagePage()),
                ),
                icon: const Icon(Icons.manage_search),
                label: const Text('스크리닝 종목 관리'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (const String.fromEnvironment('ADMIN_EMAIL').isNotEmpty &&
                authProvider.currentUser?.email ==
                    const String.fromEnvironment('ADMIN_EMAIL')) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AdminScreeningPage()),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('AI 추천 종목 검토 (관리자)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── 공지 ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '본 서비스의 모든 투자 판단 및 그 결과에 대한 책임은 '
                      '전적으로 이용자 본인에게 있습니다.\n'
                      '자동매매는 원금 손실 위험이 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'AI 매매',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5))),
        ],
      ),
    );
  }
}

// ── 하위 위젯 ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeData theme;

  const _UserCard({required this.authProvider, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            backgroundImage: authProvider.avatarUrl != null
                ? NetworkImage(authProvider.avatarUrl!)
                : null,
            child: authProvider.avatarUrl == null
                ? Icon(Icons.person, color: theme.colorScheme.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authProvider.displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (authProvider.currentUser?.email != null &&
                    authProvider.displayName != authProvider.currentUser?.email)
                  Text(authProvider.currentUser!.email!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('로그아웃'),
            style:
                TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ThemeData theme;
  final Widget child;
  const _InfoCard({required this.theme, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _StepCard extends StatelessWidget {
  final ThemeData theme;
  final String stepNumber;
  final String title;
  final String content;
  const _StepCard(
      {required this.theme,
      required this.stepNumber,
      required this.title,
      required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(stepNumber,
                style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(content,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
