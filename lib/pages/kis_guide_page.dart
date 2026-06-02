import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'trading_setup_page.dart';

class KisGuidePage extends StatelessWidget {
  const KisGuidePage({super.key});

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
          'KIS API 키 발급 가이드',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 소개 ──────────────────────────────────────────────────────
            _InfoBox(
              theme: theme,
              icon: Icons.info_outline,
              color: theme.colorScheme.primary,
              text: '한국투자증권 Open API 키를 발급받아야 자동매매를 시작할 수 있습니다.\n'
                  '아래 단계를 순서대로 따라하세요. (약 5분 소요)',
            ),
            const SizedBox(height: 28),

            // ── STEP 1 ────────────────────────────────────────────────────
            _StepHeader(theme: theme, step: '1', title: '한국투자증권 계좌 개설'),
            const SizedBox(height: 10),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '한국투자증권 앱(MTS) 또는 지점에서 계좌를 개설합니다.'),
                  _bullet(theme, '이미 한국투자증권 계좌가 있다면 이 단계는 건너뛰세요.'),
                  const SizedBox(height: 12),
                  _AppDownloadRow(theme: theme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 2 ────────────────────────────────────────────────────
            _StepHeader(theme: theme, step: '2', title: 'Open API 서비스 신청'),
            const SizedBox(height: 10),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '아래 버튼을 눌러 한국투자증권 개발자 사이트에 접속합니다.'),
                  _bullet(theme, '우측 상단 로그인 → 한국투자증권 아이디로 로그인'),
                  _bullet(theme, '상단 메뉴 "Open API" → "이용 신청"'),
                  _bullet(theme, '"실전투자" 선택 후 약관 동의 → 신청 완료'),
                  const SizedBox(height: 14),
                  _LinkButton(
                    theme: theme,
                    label: 'developers.koreainvestment.com 열기',
                    icon: Icons.open_in_new,
                    url: 'https://developers.koreainvestment.com',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 3 ────────────────────────────────────────────────────
            _StepHeader(theme: theme, step: '3', title: '앱 등록 및 App Key 발급'),
            const SizedBox(height: 10),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '로그인 후 우측 상단 "마이페이지" 클릭'),
                  _bullet(theme, '"앱 관리" → "앱 등록하기" 클릭'),
                  _bullet(theme, '앱 이름: 아무 이름이나 입력 (예: 내 자동매매)'),
                  _bullet(theme, '계좌 선택 → 실전 계좌 선택 → 등록'),
                  _bullet(theme, '등록 완료 후 앱 목록에서 App Key / App Secret 확인'),
                  const SizedBox(height: 12),
                  _HighlightBox(
                    theme: theme,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    text: 'App Secret은 최초 1회만 보여집니다.\n반드시 복사해두세요!',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 4 ────────────────────────────────────────────────────
            _StepHeader(theme: theme, step: '4', title: '계좌번호 확인'),
            const SizedBox(height: 10),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '한국투자증권 계좌번호는 보통 8자리 숫자입니다.'),
                  _bullet(theme, 'MTS 앱 → 홈 → 계좌 선택 화면에서 확인할 수 있습니다.'),
                  _bullet(theme, '계좌번호 뒤 "-01" 같은 상품코드는 별도 입력란에 씁니다.'),
                  const SizedBox(height: 12),
                  _CodeExample(
                    theme: theme,
                    label: '예시',
                    code: '계좌번호: 12345678\n상품코드: 01',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 5 ────────────────────────────────────────────────────
            _StepHeader(theme: theme, step: '5', title: 'StockWiki에 등록'),
            const SizedBox(height: 10),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(theme, '발급받은 App Key · App Secret · 계좌번호를 준비합니다.'),
                  _bullet(theme, '아래 버튼을 눌러 등록 화면으로 이동합니다.'),
                  _bullet(theme, '등록하면 자동으로 GitHub Actions에 연동됩니다.'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TradingSetupPage()),
                      ),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('API 키 등록하러 가기'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── FAQ ───────────────────────────────────────────────────────
            _SectionTitle(theme: theme, title: '자주 묻는 질문'),
            const SizedBox(height: 12),
            _FaqItem(
              theme: theme,
              question: 'API 신청 후 바로 사용할 수 있나요?',
              answer: '실전 계좌 API는 신청 즉시 발급됩니다. 단, 계좌 개설 직후에는 '
                  '영업일 1일 정도 대기가 필요할 수 있습니다.',
            ),
            _FaqItem(
              theme: theme,
              question: 'App Secret을 잃어버렸어요.',
              answer: '개발자 사이트 → 마이페이지 → 앱 관리에서 앱을 삭제하고 다시 등록하면 '
                  '새 키를 발급받을 수 있습니다.',
            ),
            _FaqItem(
              theme: theme,
              question: '자동매매가 내 계좌에 직접 접근하나요?',
              answer: '네. App Key/Secret으로 매수·매도 주문을 실행합니다. '
                  '원금 손실이 발생할 수 있으며 모든 투자 결과는 본인 책임입니다.',
            ),
            _FaqItem(
              theme: theme,
              question: '키를 언제든지 삭제할 수 있나요?',
              answer: 'API 키 등록 화면에서 "자동매매 일시 중지"로 즉시 중단할 수 있고, '
                  '한국투자증권 개발자 사이트에서 앱을 삭제하면 키가 완전히 무효화됩니다.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _bullet(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ',
                style: TextStyle(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            Expanded(
                child: Text(text,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6))),
          ],
        ),
      );
}

// ── 하위 위젯 ─────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final ThemeData theme;
  final String step;
  final String title;
  const _StepHeader({required this.theme, required this.step, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(step,
                style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );
}

class _Card extends StatelessWidget {
  final ThemeData theme;
  final Widget child;
  const _Card({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) => Container(
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

class _InfoBox extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.theme, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6))),
          ],
        ),
      );
}

class _HighlightBox extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final Color color;
  final String text;
  const _HighlightBox({required this.theme, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(height: 1.6, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _CodeExample extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String code;
  const _CodeExample({required this.theme, required this.label, required this.code});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.7)),
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final IconData icon;
  final String url;
  const _LinkButton({required this.theme, required this.label, required this.icon, required this.url});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}

class _AppDownloadRow extends StatelessWidget {
  final ThemeData theme;
  const _AppDownloadRow({required this.theme});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://apps.apple.com/kr/app/id1539710559'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.apple, size: 18),
              label: const Text('App Store'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://play.google.com/store/apps/details?id=com.truefriend.csnative'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.android, size: 18),
              label: const Text('Google Play'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final ThemeData theme;
  final String title;
  const _SectionTitle({required this.theme, required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _FaqItem extends StatefulWidget {
  final ThemeData theme;
  final String question;
  final String answer;
  const _FaqItem({required this.theme, required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.theme.dividerColor),
        ),
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.question,
                          style: widget.theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (_open) ...[
                  const SizedBox(height: 10),
                  Text(widget.answer,
                      style: widget.theme.textTheme.bodySmall
                          ?.copyWith(height: 1.6,
                              color: widget.theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      );
}
