import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/login_history_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _currentUser = Supabase.instance.client.auth.currentUser;
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      // 실제 로그인 이벤트만 이 기기 기록에 남긴다 (세션 복원·토큰 갱신 제외)
      if (data.event == AuthChangeEvent.signedIn) {
        final provider =
            data.session?.user.appMetadata['provider'] as String? ?? 'email';
        LoginHistoryService.record(provider);
      }
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  String get displayName {
    if (_currentUser == null) return '';
    final meta = _currentUser!.userMetadata;
    return (meta?['full_name'] as String?) ??
        (meta?['name'] as String?) ??
        (meta?['preferred_username'] as String?) ??
        (_currentUser!.email ?? '');
  }

  String? get avatarUrl {
    return _currentUser?.userMetadata?['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
