import 'package:supabase_flutter/supabase_flutter.dart';

/// 빌드 시 `--dart-define=ADMIN_EMAIL=...` 로 주입되는 관리자 계정 이메일.
const String kAdminEmail = String.fromEnvironment('ADMIN_EMAIL');

/// 현재 로그인한 사용자가 관리자인지 여부.
/// ADMIN_EMAIL 이 주입되지 않았거나 로그인하지 않았으면 false.
bool get isAdminUser {
  if (kAdminEmail.isEmpty) return false;
  final email = Supabase.instance.client.auth.currentUser?.email;
  return email != null && email.toLowerCase() == kAdminEmail.toLowerCase();
}

/// 임의의 이메일이 관리자 계정인지 (이미 이메일을 알고 있을 때).
bool isAdminEmail(String? email) =>
    kAdminEmail.isNotEmpty &&
    email != null &&
    email.toLowerCase() == kAdminEmail.toLowerCase();
