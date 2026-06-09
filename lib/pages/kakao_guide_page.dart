import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('개요', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '카카오톡 알림을 받으려면 카카오 개발자 사이트에서 앱을 등록하고 REST API Key와 리다이렉트 URL을 설정한 뒤, 사용자 인증을 통해 얻은 refresh_token을 등록해야 합니다.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          Text('1) 앱 등록', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('developers.kakao.com에 접속 → "내 애플리케이션" → 새 앱 등록', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),

          Text('2) 플랫폼·리다이렉트 URI 설정', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('앱 설정 → 플랫폼에 웹(혹은 로컬) 리다이렉트 URI를 추가하세요. 예: https://stockwiki.vercel.app/_kakao_callback 또는 http://localhost:3000/auth/kakao',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),

          Text('3) REST API Key 복사', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('앱 키에서 "REST API Key"를 복사합니다. 이 키는 서버(Functions 또는 Actions)의 환경변수로만 보관하세요.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),

          Text('4) 사용자 토큰 발급 (권한: talk_message)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('아래 인증 URL을 브라우저에 붙여넣어 로그인하면 리다이렉트된 주소의 code를 얻을 수 있습니다. 요청 시 scope에 talk_message를 포함해야 메시지 권한이 부여됩니다.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          SelectableText(
            'https://kauth.kakao.com/oauth/authorize?client_id={REST_API_KEY}&redirect_uri={REDIRECT_URI}&response_type=code&scope=talk_message,profile',
            style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),

          Text('5) code → 토큰 교환', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(
            'POST https://kauth.kakao.com/oauth/token',
            style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          SelectableText(
            'grant_type=authorization_code&client_id={REST_API_KEY}&redirect_uri={REDIRECT_URI}&code={AUTH_CODE}',
            style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),

          Text('응답에서 access_token과 refresh_token이 반환됩니다. 앱 사용자(본인)에게 메시지를 보내려면 refresh_token을 저장해 주세요. (refresh_token은 기본 60일 유효)',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
            ),
            child: Text('주의: refresh_token은 민감정보입니다. 앱에서는 refresh_token만 서버에 저장하고 REST API Key는 서버 환경변수로 보관하세요.', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://developers.kakao.com')),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Kakao Developers 열기'),
            ),
          ),
          const SizedBox(height: 20),

          Text('앱에 등록하기', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('발급받은 refresh_token을 앱의 "API 키 등록" 화면의 카카오 리프레시 토큰 필드에 붙여넣고 저장하세요.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),

          Text('테스트', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('서버에 REST API Key와 refresh_token이 정상 등록되면 스크리닝 실행 시 등록된 사용자에게 카카오 메시지가 전송됩니다. 토큰 만료 시 재발급 후 재등록하세요.', style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
