import 'package:flutter/material.dart';

class KakaoGuideContent extends StatelessWidget {
  const KakaoGuideContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '대부분의 경우 이 페이지는 필요 없습니다. 설정 화면의 "카카오 알림 연동하기" 버튼을 누르고 카카오 로그인만 하면 자동으로 연동됩니다. 개발자 앱을 직접 만들거나 API를 직접 호출할 필요가 없어요.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('원클릭 연동은 어떻게 동작하나요?',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '"카카오 알림 연동하기" 버튼을 누르면 StockWiki가 이미 등록해 둔 카카오 앱으로 로그인 화면이 열립니다. 회원님 본인 카카오 계정으로 로그인·동의하면, 그 결과(인가 코드)를 StockWiki 서버가 받아 토큰 교환까지 자동으로 처리하고 저장합니다. 서비스마다 새 앱을 만드는 게 아니라, 앱은 하나를 공유하고 로그인한 계정별로 다른 알림 토큰이 발급되는 방식입니다.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text('버튼이 비활성화되어 있어요',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '증권사(KIS) API 정보를 먼저 저장해야 연동 버튼이 활성화됩니다. 위쪽 증권사 설정을 먼저 저장한 뒤 다시 시도해주세요.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text('아래 "리프레시 토큰 직접 입력" 칸은 언제 쓰나요?',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '이미 유효한 카카오 refresh_token을 다른 경로로 가지고 있는 경우(예: 관리자가 직접 발급한 토큰)에만 붙여넣는 용도입니다. 일반적으로 직접 발급할 필요는 없고, 위 원클릭 버튼을 이용해주세요. refresh_token은 보통 60일간 유효하며, 만료되면 다시 연동하면 됩니다.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text('그래도 연동이 안 될 때',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '스낵바에 표시되는 실패 메시지를 캡처해서 관리자에게 문의해주세요.',
          style: theme.textTheme.bodySmall,
        ),
      ]),
    );
  }
}

class KakaoGuidePage extends StatelessWidget {
  const KakaoGuidePage({super.key});

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
        title: Text('카카오톡 키 발급 가이드',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface)),
      ),
      body: const KakaoGuideContent(),
    );
  }
}
