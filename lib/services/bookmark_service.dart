import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/stock.dart';

/// 북마크(관심종목) 서비스
///
/// 로그인 상태: Supabase `bookmarks` 테이블에 저장 → 계정 기준으로 기기 간 동기화됨
/// 비로그인 상태: SharedPreferences(로컬)에 저장 — 기존 게스트 동작 유지
class BookmarkService {
  static const String _bookmarkKey = 'bookmarked_stocks';
  static const String _bookmarkDetailsKey = 'bookmark_details';

  static SupabaseClient get _sb => Supabase.instance.client;
  static User? get _user => _sb.auth.currentUser;

  /// 북마크 목록 가져오기
  static Future<Set<String>> getBookmarkedStocks() async {
    final user = _user;
    if (user != null) {
      try {
        final rows = await _sb
            .from('bookmarks')
            .select('stock_code')
            .eq('user_id', user.id);
        return rows.map((r) => r['stock_code'] as String).toSet();
      } catch (e) {
        debugPrint('북마크 로드 오류(cloud): $e');
        return <String>{};
      }
    }
    return _localGetBookmarkedStocks();
  }

  /// 북마크 추가
  static Future<bool> addBookmark(
      String stockCode, Map<String, dynamic> details) async {
    final user = _user;
    if (user != null) {
      try {
        await _sb.from('bookmarks').upsert({
          'user_id': user.id,
          'stock_code': stockCode,
          'stock_name': details['stockName'] ?? '',
          'type': details['type'] ?? 'kr',
          'price': details['price'],
          'change_percent': details['changePercent'],
          'change': details['change'],
        }, onConflict: 'user_id,stock_code');
        return true;
      } catch (e) {
        debugPrint('북마크 추가 오류(cloud): $e');
        return false;
      }
    }
    return _localAddBookmark(stockCode, details);
  }

  /// 북마크 제거
  static Future<bool> removeBookmark(String stockCode) async {
    final user = _user;
    if (user != null) {
      try {
        await _sb
            .from('bookmarks')
            .delete()
            .eq('user_id', user.id)
            .eq('stock_code', stockCode);
        return true;
      } catch (e) {
        debugPrint('북마크 제거 오류(cloud): $e');
        return false;
      }
    }
    return _localRemoveBookmark(stockCode);
  }

  /// 북마크 여부 확인
  static Future<bool> isBookmarked(String stockCode) async {
    final bookmarks = await getBookmarkedStocks();
    return bookmarks.contains(stockCode);
  }

  /// 북마크 상세 정보 가져오기
  static Future<Map<String, dynamic>?> getBookmarkDetails(
      String stockCode) async {
    final all = await getAllBookmarkDetails();
    for (final b in all) {
      if (b['stockCode'] == stockCode) return b;
    }
    return null;
  }

  /// Stock 객체로 관심종목 추가 (미국/국내 공통)
  static Future<bool> addStock(Stock stock, {String type = 'us'}) async {
    return addBookmark(stock.symbol, {
      'stockName': stock.name,
      'symbol': stock.symbol,
      'type': type,
      'price': stock.price,
      'changePercent': stock.changePercent,
      'change': stock.change,
    });
  }

  /// 모든 북마크 상세 정보 가져오기 (최신순)
  static Future<List<Map<String, dynamic>>> getAllBookmarkDetails() async {
    final user = _user;
    if (user != null) {
      try {
        final rows = await _sb
            .from('bookmarks')
            .select()
            .eq('user_id', user.id)
            .order('bookmarked_at', ascending: false);
        return rows
            .map<Map<String, dynamic>>((r) => {
                  'stockCode': r['stock_code'],
                  'symbol': r['stock_code'],
                  'stockName': r['stock_name'],
                  'type': r['type'],
                  'price': r['price'],
                  'changePercent': r['change_percent'],
                  'change': r['change'],
                  'bookmarkedAt': r['bookmarked_at'],
                })
            .toList();
      } catch (e) {
        debugPrint('북마크 상세 정보 로드 오류(cloud): $e');
        return [];
      }
    }
    return _localGetAllBookmarkDetails();
  }

  /// 로그인 직후 1회 호출 — 로컬(게스트) 북마크를 계정으로 업로드
  /// 이미 클라우드에 있는 종목은 건드리지 않고, 로컬에만 있던 것만 올림
  static Future<void> migrateLocalToCloud() async {
    final user = _user;
    if (user == null) return;

    final localDetails = await _localGetAllBookmarkDetails();
    if (localDetails.isEmpty) return;

    try {
      final cloudCodes = await getBookmarkedStocks();
      final rowsToUpload = localDetails
          .where((d) => !cloudCodes.contains(d['stockCode']))
          .map((d) => {
                'user_id': user.id,
                'stock_code': d['stockCode'],
                'stock_name': d['stockName'] ?? '',
                'type': d['type'] ?? 'kr',
                'price': d['price'],
                'change_percent': d['changePercent'],
                'change': d['change'],
              })
          .toList();

      if (rowsToUpload.isNotEmpty) {
        await _sb
            .from('bookmarks')
            .upsert(rowsToUpload, onConflict: 'user_id,stock_code');
      }

      // 업로드 완료 후 로컬 저장소는 비움 (이후 이 계정의 진실 소스는 클라우드)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarkKey);
      await prefs.remove(_bookmarkDetailsKey);
    } catch (e) {
      debugPrint('북마크 마이그레이션 오류: $e');
    }
  }

  // ── 로컬(게스트) 저장소 ──────────────────────────────────────────────────

  static Future<Set<String>> _localGetBookmarkedStocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString(_bookmarkKey);
      if (bookmarksJson != null) {
        final List<dynamic> bookmarks = json.decode(bookmarksJson);
        return bookmarks.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('북마크 로드 오류: $e');
    }
    return <String>{};
  }

  static Future<bool> _localAddBookmark(
      String stockCode, Map<String, dynamic> details) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bookmarks = await _localGetBookmarkedStocks();
      bookmarks.add(stockCode);
      await prefs.setString(_bookmarkKey, json.encode(bookmarks.toList()));

      final detailsJson = prefs.getString(_bookmarkDetailsKey);
      Map<String, dynamic> allDetails = {};
      if (detailsJson != null) {
        allDetails = json.decode(detailsJson);
      }
      allDetails[stockCode] = {
        ...details,
        'bookmarkedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_bookmarkDetailsKey, json.encode(allDetails));

      return true;
    } catch (e) {
      debugPrint('북마크 추가 오류: $e');
      return false;
    }
  }

  static Future<bool> _localRemoveBookmark(String stockCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bookmarks = await _localGetBookmarkedStocks();
      bookmarks.remove(stockCode);
      await prefs.setString(_bookmarkKey, json.encode(bookmarks.toList()));

      final detailsJson = prefs.getString(_bookmarkDetailsKey);
      if (detailsJson != null) {
        Map<String, dynamic> allDetails = json.decode(detailsJson);
        allDetails.remove(stockCode);
        await prefs.setString(_bookmarkDetailsKey, json.encode(allDetails));
      }

      return true;
    } catch (e) {
      debugPrint('북마크 제거 오류: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>>
      _localGetAllBookmarkDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await _localGetBookmarkedStocks();
      final detailsJson = prefs.getString(_bookmarkDetailsKey);

      if (detailsJson == null) return [];

      final Map<String, dynamic> allDetails = json.decode(detailsJson);
      final List<Map<String, dynamic>> result = [];

      for (final stockCode in bookmarks) {
        final details = allDetails[stockCode];
        if (details != null) {
          result.add({
            'stockCode': stockCode,
            ...details,
          });
        }
      }

      result.sort((a, b) {
        final aTime = a['bookmarkedAt'] as String? ?? '';
        final bTime = b['bookmarkedAt'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      return result;
    } catch (e) {
      debugPrint('북마크 상세 정보 로드 오류: $e');
      return [];
    }
  }
}
