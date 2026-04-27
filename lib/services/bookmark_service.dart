import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/stock.dart';

/// 북마크 서비스
/// SharedPreferences를 사용하여 북마크된 종목을 영구 저장
class BookmarkService {
  static const String _bookmarkKey = 'bookmarked_stocks';
  static const String _bookmarkDetailsKey = 'bookmark_details';

  /// 북마크 목록 가져오기
  static Future<Set<String>> getBookmarkedStocks() async {
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

  /// 북마크 추가
  static Future<bool> addBookmark(String stockCode, Map<String, dynamic> details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 북마크 목록에 추가
      final bookmarks = await getBookmarkedStocks();
      bookmarks.add(stockCode);
      await prefs.setString(_bookmarkKey, json.encode(bookmarks.toList()));
      
      // 북마크 상세 정보 저장
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

  /// 북마크 제거
  static Future<bool> removeBookmark(String stockCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 북마크 목록에서 제거
      final bookmarks = await getBookmarkedStocks();
      bookmarks.remove(stockCode);
      await prefs.setString(_bookmarkKey, json.encode(bookmarks.toList()));
      
      // 북마크 상세 정보에서 제거
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

  /// 북마크 여부 확인
  static Future<bool> isBookmarked(String stockCode) async {
    final bookmarks = await getBookmarkedStocks();
    return bookmarks.contains(stockCode);
  }

  /// 북마크 상세 정보 가져오기
  static Future<Map<String, dynamic>?> getBookmarkDetails(String stockCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailsJson = prefs.getString(_bookmarkDetailsKey);
      if (detailsJson != null) {
        final Map<String, dynamic> allDetails = json.decode(detailsJson);
        return allDetails[stockCode];
      }
    } catch (e) {
      debugPrint('북마크 상세 정보 로드 오류: $e');
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

  /// 모든 북마크 상세 정보 가져오기
  static Future<List<Map<String, dynamic>>> getAllBookmarkDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await getBookmarkedStocks();
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
      
      // 북마크한 시간순으로 정렬 (최신순)
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
