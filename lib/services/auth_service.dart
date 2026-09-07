import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  // OAuth 리디렉션 URL — 웹은 현재 브라우저 origin, 모바일은 딥링크 스킴
  static String? get _redirectTo {
    if (!kIsWeb) return 'io.supabase.stockwiki://login-callback/';
    // Uri.base.origin = 현재 브라우저 주소의 origin (배포 시 stockwiki.vercel.app)
    return Uri.base.origin;
  }

  // ── 소셜 로그인 ──────────────────────────────────────────────────────────────
  static Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectTo,
    );
  }

  static Future<void> signInWithKakao() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: _redirectTo,
    );
  }

  // ── 이메일 / 비밀번호 ──────────────────────────────────────────────────────
  static Future<AuthResponse> signInWithEmail(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  // ── 로그아웃 ─────────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ── 회원 탈퇴 ────────────────────────────────────────────────────────────────
  /// 서버(delete-account 엣지 함수)에서 계정과 연결 데이터를 삭제한 뒤 로그아웃한다.
  /// bookmarks / trading_configs / screening_candidates 는 auth.users 삭제 시
  /// ON DELETE CASCADE 로 함께 지워진다.
  static Future<void> deleteAccount() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');

    final res = await _supabase.functions.invoke('delete-account');
    if (res.status >= 400) {
      final msg = (res.data as Map?)?['error'] ?? '계정 삭제에 실패했습니다.';
      throw Exception(msg);
    }

    await _supabase.auth.signOut();
  }
}
