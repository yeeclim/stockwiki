import 'package:flutter/foundation.dart';
import '../services/bookmark_service.dart';

/// 북마크 상태를 앱 전역에서 공유하는 Provider
/// 여러 페이지에서 북마크 변경 시 즉시 다른 페이지도 반영됨
class BookmarkProvider extends ChangeNotifier {
  Set<String> _bookmarks = {};
  bool _isLoaded = false;

  Set<String> get bookmarks => _bookmarks;
  bool get isLoaded => _isLoaded;

  bool isBookmarked(String stockCode) => _bookmarks.contains(stockCode);

  Future<void> load() async {
    if (_isLoaded) return;
    _bookmarks = await BookmarkService.getBookmarkedStocks();
    _isLoaded = true;
    notifyListeners();
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
