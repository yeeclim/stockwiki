import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/bookmark_service.dart';

/// 북마크 상태를 앱 전역에서 공유하는 Provider
/// 여러 페이지에서 북마크 변경 시 즉시 다른 페이지도 반영됨
class BookmarkProvider extends ChangeNotifier {
  Set<String> _bookmarks = {};
  bool _isLoaded = false;
  StreamSubscription<AuthState>? _authSubscription;
  User? _lastUser;

  BookmarkProvider() {
    _lastUser = Supabase.instance.client.auth.currentUser;
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final wasLoggedIn = _lastUser != null;
      final nowUser = data.session?.user;
      _lastUser = nowUser;

      if (!wasLoggedIn && nowUser != null) {
        // 로그인 직후 1회: 게스트로 저장해둔 로컬 북마크를 계정으로 업로드
        await BookmarkService.migrateLocalToCloud();
      }
      // 로그인/로그아웃으로 데이터 소스(클라우드↔로컬)가 바뀌므로 강제 재로딩
      _isLoaded = false;
      await load();
    });
  }

  Set<String> get bookmarks => _bookmarks;
  bool get isLoaded => _isLoaded;

  bool isBookmarked(String stockCode) => _bookmarks.contains(stockCode);

  Future<void> load() async {
    if (_isLoaded) return;
    _bookmarks = await BookmarkService.getBookmarkedStocks();
    _isLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> add(String stockCode, Map<String, dynamic> details) async {
    final ok = await BookmarkService.addBookmark(stockCode, details);
    if (ok) {
      _bookmarks.add(stockCode);
      notifyListeners();
    }
  }

  Future<void> remove(String stockCode) async {
    final ok = await BookmarkService.removeBookmark(stockCode);
    if (ok) {
      _bookmarks.remove(stockCode);
      notifyListeners();
    }
  }

  Future<void> toggle(String stockCode, Map<String, dynamic> details) async {
    if (isBookmarked(stockCode)) {
      await remove(stockCode);
    } else {
      await add(stockCode, details);
    }
  }
}
