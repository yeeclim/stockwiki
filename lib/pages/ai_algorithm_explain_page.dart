import 'package:flutter/material.dart';

class AiAlgorithmExplainPage extends StatelessWidget {
  const AiAlgorithmExplainPage({super.key});

  Widget _sectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI 종목 선정 알고리즘 설명'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'StockWiki의 AI는 다양한 지표와 뉴스 데이터를 종합해 종목을 선별합니다.\n'
                '본 페이지는 그 핵심 로직을 이해하기 쉽게 요약한 문서입니다.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            ),
            _sectionTitle(context, '1. 데이터 소스'),
            _bullet(context, '가격/거래대금: 일중 및 일봉 기준 변동성, 추세, 거래량 급증 감지'),
            _bullet(context, '재무지표: 매출/영업이익 성장률, 이익률, 부채비율, 현금흐름'),
            _bullet(context, '밸류에이션: PER/PBR/PSR 등 동종업계 대비 상대가치'),
            _bullet(context, '뉴스/키워드: 최신 뉴스, 테마 키워드, 긍/부정 감성 점수'),
            _bullet(context, '대외지표: 환율, 원자재(WTI/금/은), 크립토, 공포탐욕 지수'),
            _sectionTitle(context, '2. 전처리와 표준화'),
            _bullet(context, '결측치 대체와 이상치 클리핑으로 극단치 영향 완화'),
            _bullet(context, '기간 정규화: 단기/중기/장기 윈도우로 수익률·변동성 표준화'),
            _bullet(context, '산업군/시가총액별 스케일링으로 비교 가능성 확보'),
            _sectionTitle(context, '3. 특징 엔지니어링'),
            _bullet(context, '모멘텀: 1/3/6/12개월 수익률과 추세 일관성'),
            _bullet(context, '수급: 거래대금 급증, 고점 돌파 동반 여부'),
            _bullet(context, '퀄리티: ROE/영업이익률의 추세 및 변동성'),
            _bullet(context, '밸류: 동종 업계 대비 밸류에이션 디스카운트'),
            _bullet(context, '리스크: 변동성, 낙폭 대비 회복탄력(반등력) 지표'),
            _bullet(context, '뉴스/키워드: 테마 매칭 점수와 감성 점수 가중 합'),
            _sectionTitle(context, '4. 점수화와 가중치'),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '각 특징을 0~100 점수로 정규화한 뒤, 아래 가중치로 합산합니다.\n'
                '시장 국면에 따라 가중치는 동적으로 조정될 수 있습니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _bullet(context,
                '모멘텀 30% · 수급 20% · 퀄리티 20% · 밸류 15% · 리스크 10% · 뉴스 5%'),
            _sectionTitle(context, '5. 리밸런싱과 홀딩기간'),
            _bullet(context, '기본 리밸런싱 주기: 4주 (테마/시장상황에 따라 2~12주 가변)'),
            _bullet(context, '테마별 권장 보유기간을 반영(예: 방산/바이오는 상대적으로 장기)'),
            _sectionTitle(context, '6. 리스크 관리'),
            _bullet(context, '개별 종목 최대 비중 제한, 동일 테마·섹터 과도 편중 방지'),
            _bullet(context, '손절/이익실현 가이드라인 제시(예: -10% 손절, +20% 분할청산 등)'),
            _bullet(context, '시장 급변 시 캐시 비중 확대 옵션'),
            _sectionTitle(context, '7. 유의사항'),
            _bullet(context, '본 알고리즘은 투자 판단 보조 도구이며, 수익을 보장하지 않습니다.'),
            _bullet(context, '과거 데이터 기반 모델이므로 예기치 못한 이벤트에는 취약할 수 있습니다.'),
            _bullet(context, '최종 투자 결정과 책임은 투자자 본인에게 있습니다.'),
            const SizedBox(height: 48),
            Center(
              child: Text(
                '마지막 업데이트: 2025-10',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
