import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'trading_setup_page.dart';
import 'kakao_guide_page.dart';

class KisGuidePage extends StatefulWidget {
  const KisGuidePage({super.key});

  @override
  State<KisGuidePage> createState() => _KisGuidePageState();
}

class _KisGuidePageState extends State<KisGuidePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _brokers = [
    _BrokerInfo(
      id: 'kis',
      name: '한국투자증권',
      shortName: '한국투자',
      color: Color(0xFF0066CC),
      devUrl: 'https://apiportal.koreainvestment.com',
      signupUrl: 'https://www.truefriend.com',
      iosUrl: 'https://apps.apple.com/kr/app/id1539710559',
      aosUrl:
          'https://play.google.com/store/apps/details?id=com.truefriend.csnative',
      steps: [
        '한국투자증권 앱(MTS)으로 계좌를 개설합니다.',
        'developers.koreainvestment.com 접속 → 로그인',
        '"Open API" 메뉴 → "이용 신청" → 실전 계좌 선택',
        '"마이페이지" → "앱 관리" → "앱 등록하기"',
        '앱 이름 입력 후 등록 → App Key · App Secret 발급',
        'App Secret은 최초 1회만 표시됩니다. 반드시 복사하세요!',
      ],
      secretNote: 'App Secret은 최초 1회만 보여집니다. 바로 복사해두세요!',
    ),
    _BrokerInfo(
      id: 'kiwoom',
      name: '키움증권',
      shortName: '키움',
      color: Color(0xFFE8001C),
      devUrl: 'https://openapi.kiwoom.com',
      signupUrl: 'https://www.kiwoom.com',
      iosUrl: 'https://apps.apple.com/kr/app/id594911206',
      aosUrl:
          'https://play.google.com/store/apps/details?id=com.kiwoom.ksystem.hero',
      steps: [
        '키움증권 영웅문 앱으로 계좌를 개설합니다.',
        'openapi.kiwoom.com 접속 → 로그인',
        '"OpenAPI+" 메뉴 → "사용 신청" → 실전 계좌 선택',
        '"앱 등록" → 앱 이름 입력 후 등록',
        'App Key · App Secret 발급 완료',
        '계좌번호는 영웅문 홈 화면에서 확인합니다.',
      ],
      secretNote: 'App Secret은 최초 1회만 보여집니다. 즉시 복사해두세요!',
    ),
    _BrokerInfo(
      id: 'nh',
      name: 'NH투자증권 (나무)',
      shortName: '나무',
      color: Color(0xFF00A651),
      devUrl: 'https://open.nhqv.com',
      signupUrl: 'https://www.nhqv.com',
      iosUrl: 'https://apps.apple.com/kr/app/id1437666065',
      aosUrl: 'https://play.google.com/store/apps/details?id=com.nhqv.namuh',
      steps: [
        'NH투자증권 나무 앱으로 계좌를 개설합니다.',
        'open.nhqv.com 접속 → NH투자증권 로그인',
        '"Open API" → "서비스 신청" → 실전 계좌 연결',
        '"앱 등록" 클릭 → 앱 이름 입력 후 등록',
        'App Key · App Secret 발급 완료',
        '계좌번호는 나무 앱 홈 화면에서 확인합니다.',
      ],
      secretNote: 'Secret Key는 재발급이 필요하면 앱 삭제 후 재등록하세요.',
    ),
    _BrokerInfo(
      id: 'samsung',
      name: '삼성증권',
      shortName: '삼성',
      color: Color(0xFF1428A0),
      devUrl: 'https://openapi.samsungpop.com',
      signupUrl: 'https://www.samsungpop.com',
      iosUrl: 'https://apps.apple.com/kr/app/id370152619',
      aosUrl:
          'https://play.google.com/store/apps/details?id=com.samsung.android.spop.mts',
      steps: [
        '삼성증권 mPOP 앱으로 계좌를 개설합니다.',
        'openapi.samsungpop.com 접속 → 삼성증권 로그인',
        '"Open API 신청" → 실전 투자 계좌 선택',
        '"앱 등록" → 앱 이름 입력 후 등록',
        'App Key · App Secret 발급 완료',
        '계좌번호는 mPOP 앱에서 확인합니다.',
      ],
      secretNote: 'App Secret을 분실한 경우 앱을 재등록하여 재발급받으세요.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // add one more tab for Kakao guide
    _tab = TabController(length: _brokers.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          'API 키 발급 가이드',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            ..._brokers.map((b) => Tab(
                child: Text(b.shortName,
                    style: const TextStyle(fontWeight: FontWeight.bold)))),
            const Tab(
                child:
                    Text('카카오', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ..._brokers.map((b) => _BrokerGuideTab(broker: b, theme: theme)),
          // Kakao guide as its own tab
          Padding(padding: const EdgeInsets.all(0), child: KakaoGuideContent()),
        ],
      ),
    );
  }
}

// ── 증권사별 탭 내용 ──────────────────────────────────────────────────────────

class _BrokerGuideTab extends StatelessWidget {
  final _BrokerInfo broker;
  final ThemeData theme;

  const _BrokerGuideTab({required this.broker, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: broker.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: broker.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: broker.color,
                  child: Text(
                    broker.shortName[0],
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broker.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Open API 키 발급 방법',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 단계별 가이드 ─────────────────────────────────────────────
          Text('① API 키 발급 단계',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...broker.steps.asMap().entries.map((e) => _StepRow(
                theme: theme,
                index: e.key + 1,
                text: e.value,
                color: broker.color,
                isLast: e.key == broker.steps.length - 1,
              )),
          const SizedBox(height: 8),

          // ── 경고 박스 ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(broker.secretNote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(height: 1.6, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 개발자 사이트 이동 ─────────────────────────────────────────
          _OutlineBtn(
            label: '${broker.name} 개발자 사이트 열기',
            icon: Icons.open_in_new,
            onTap: () => _open(broker.devUrl),
            fullWidth: true,
          ),
          const SizedBox(height: 28),

          // ── FAQ ───────────────────────────────────────────────────────
          Text('자주 묻는 질문',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _FaqItem(
            theme: theme,
            question: 'API 신청 후 바로 사용할 수 있나요?',
            answer:
                '실전 계좌 API는 신청 즉시 발급됩니다. 단, 계좌 개설 직후에는 영업일 1일 정도 대기가 필요할 수 있습니다.',
          ),
          _FaqItem(
            theme: theme,
            question: 'App Secret을 잃어버렸어요.',
            answer: '개발자 사이트 → 앱 관리에서 앱을 삭제하고 재등록하면 새 키를 발급받을 수 있습니다.',
          ),
          _FaqItem(
            theme: theme,
            question: '자동매매가 내 계좌에 직접 접근하나요?',
            answer:
                '네. App Key/Secret으로 매수·매도 주문을 실행합니다. 원금 손실이 발생할 수 있으며 모든 투자 결과는 본인 책임입니다.',
          ),
          const SizedBox(height: 24),

          // ── 등록 버튼 ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TradingSetupPage(initialBroker: broker.id),
                ),
              ),
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text('${broker.shortName} API 키 등록하러 가기'),
              style: FilledButton.styleFrom(
                backgroundColor: broker.color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ── 데이터 모델 ───────────────────────────────────────────────────────────────

class _BrokerInfo {
  final String id;
  final String name;
  final String shortName;
  final Color color;
  final String devUrl;
  final String signupUrl;
  final String iosUrl;
  final String aosUrl;
  final List<String> steps;
  final String secretNote;

  const _BrokerInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.devUrl,
    required this.signupUrl,
    required this.iosUrl,
    required this.aosUrl,
    required this.steps,
    required this.secretNote,
  });
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final ThemeData theme;
  final int index;
  final String text;
  final Color color;
  final bool isLast;

  const _StepRow({
    required this.theme,
    required this.index,
    required this.text,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text('$index',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: color.withValues(alpha: 0.2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Text(text,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool fullWidth;

  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class _FaqItem extends StatefulWidget {
  final ThemeData theme;
  final String question;
  final String answer;
  const _FaqItem(
      {required this.theme, required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      color: widget.theme.colorScheme.onSurfaceVariant),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 10),
                Text(widget.answer,
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: widget.theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
