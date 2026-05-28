import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  // OAuth 리디렉션 URL — 웹은 현재 origin, 모바일은 딥링크 스킴
  static String? get _redirectTo =>
      kIsWeb ? null : 'io.supabase.stockwiki://login-callback/';

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
}
