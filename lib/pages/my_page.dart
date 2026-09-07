import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/login_history_service.dart';
import 'ai_trading_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
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
          '마이페이지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 프로필 카드 ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    backgroundImage: authProvider.avatarUrl != null
                        ? NetworkImage(authProvider.avatarUrl!)
                        : null,
                    child: authProvider.avatarUrl == null
                        ? Icon(Icons.person,
                            size: 32, color: theme.colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.displayName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (authProvider.currentUser?.email != null &&
                            authProvider.displayName !=
                                authProvider.currentUser?.email)
                          Text(
                            authProvider.currentUser!.email!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '회원',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 최근 로그인 (이 기기) ───────────────────────────────────────
            _LoginHistoryCard(relTime: _relTime),

            const SizedBox(height: 24),

            // ── 메뉴 리스트 ─────────────────────────────────────────────────
            _MenuTile(
              icon: Icons.smart_toy,
              iconColor: Colors.deepOrange,
              title: 'AI 자동매매',
              subtitle: 'KIS API 설정 · 매매 전략 안내',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiTradingPage()),
              ),
            ),

            const SizedBox(height: 32),

            // ── 로그아웃 ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 회원 탈퇴 ───────────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: () => _confirmDeleteAccount(context),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                child: const Text('회원 탈퇴',
                    style: TextStyle(
                        fontSize: 13, decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '계정과 함께 관심종목·자동매매 설정·스크리닝 종목이 모두 삭제되며 복구할 수 없습니다.\n\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.deleteAccount();
      await LoginHistoryService.clear();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 닫기
      Navigator.of(context).pop(); // 마이페이지 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴 실패: $e')),
      );
    }
  }
}

class _LoginHistoryCard extends StatelessWidget {
  final String Function(DateTime) relTime;
  const _LoginHistoryCard({required this.relTime});

  IconData _icon(String provider) {
    switch (provider) {
      case 'google':
        return Icons.g_mobiledata;
      case 'kakao':
        return Icons.chat_bubble;
      case 'email':
        return Icons.mail_outline;
      default:
        return Icons.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<LoginRecord>>(
      future: LoginHistoryService.load(),
      builder: (context, snap) {
        final records = snap.data ?? const [];
        if (records.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('최근 로그인 (이 기기)',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              for (final r in records)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(_icon(r.provider),
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(r.providerLabel, style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(relTime(r.at),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
