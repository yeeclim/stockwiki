import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class KrxLoader {
  static List<Map<String, dynamic>>? _mergedList;
  static Map<String, dynamic>? _stockCache;
  static DateTime? _lastUpdate;

  // 실시간 주식 데이터 가져오기 (Yahoo Finance API 사용)
  static Future<Map<String, dynamic>?> _fetchRealTimeStock(String symbol) async {
    try {
      // 캐시 확인 (5분 이내 데이터면 캐시 사용)
      if (_stockCache != null && _lastUpdate != null) {
        final now = DateTime.now();
        if (now.difference(_lastUpdate!).inMinutes < 5) {
          return _stockCache![symbol];
        }
      }

      dev.log('네이버 금융 API 호출 시작: $symbol');
      
      // API 호출 시도 (현재 도메인 사용)
      final baseUrl = Uri.base.origin;
      final url = '$baseUrl/api/naver-stock?symbol=$symbol';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      );

      dev.log('API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        dev.log('API 응답 데이터: $data');

        if (data['success'] == true && data['data'] != null) {
          final stockData = data['data'];

          final result = {
            'symbol': symbol,
            'name': stockData['name'] ?? symbol,
            'price': stockData['price']?.toDouble() ?? 0.0,
            'change': stockData['change']?.toDouble() ?? 0.0,
            'changePercent': stockData['changePercent']?.toDouble() ?? 0.0,
            'volume': stockData['volume']?.toInt() ?? 0,
            'marketCap': stockData['marketCap']?.toInt() ?? 0,
            'lastUpdate': DateTime.now().toIso8601String(),
          };

          dev.log('주식 데이터 파싱 완료: $result');

          // 캐시 업데이트
          _stockCache ??= {};
          _stockCache![symbol] = result;
          _lastUpdate = DateTime.now();

          return result;
        } else {
          dev.log('API 응답에서 데이터를 찾을 수 없습니다: ${data['error']}');
          return null;
        }
      } else {
        dev.log('API 호출 실패: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      dev.log('실시간 주식 데이터 가져오기 실패: $e');
      return null;
    }
  }


  // JSON 데이터를 한 번만 불러오고 병합 (기본 정보용)
  static Future<void> _loadData() async {
    if (_mergedList != null) return;

    try {
      dev.log('KRX 기본 데이터 로딩 시작...');
    final basicRes = await http.get(Uri.base.resolve('assets/krx_basic_info.json'));

      if (basicRes.statusCode == 200) {
    final basicJson = utf8.decode(basicRes.bodyBytes);
    final basicList = json.decode(basicJson) as List;

    _mergedList = basicList.map<Map<String, dynamic>>((item) {
          return {...item};
    }).toList();
        
        dev.log('KRX 기본 데이터 로딩 완료: ${_mergedList!.length}개 종목');
      } else {
        dev.log('KRX 기본 데이터 로딩 실패: ${basicRes.statusCode}');
        _mergedList = [];
      }
    } catch (e) {
      dev.log('KRX 기본 데이터 로딩 오류: $e');
      _mergedList = [];
    }
  }

  // ✅ 단일 결과 반환 (실시간 데이터 포함)
  static Future<Map<String, dynamic>> searchStock(String keyword) async {
    dev.log('주식 검색 시작: $keyword');
    await _loadData();
    final q = keyword.trim();

    // 더 유연한 검색어 검증 (한글, 영문, 숫자, 공백 허용)
    final isValid = RegExp(r'^[가-힣a-zA-Z0-9\s]+$').hasMatch(q) && q.length >= 1;
    if (!isValid) {
      dev.log('잘못된 검색어 형식: $q');
      throw Exception('검색어는 한글, 영문, 숫자만 입력 가능합니다.');
    }

    if (_mergedList == null || _mergedList!.isEmpty) {
      dev.log('기본 데이터가 로드되지 않았습니다.');
      throw Exception('데이터 로딩 실패');
    }

    dev.log('기본 데이터에서 검색 중... (총 ${_mergedList!.length}개 종목)');

    // 기본 정보에서 검색 (대소문자 구분 없이, 한글 종목명과 한글 종목약명 모두 확인)
    final exactMatch = _mergedList!.firstWhere(
      (stock) {
        final name = stock['한글 종목명'].toString().toLowerCase();
        final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
        final searchTerm = q.toLowerCase();
        return name == searchTerm || shortName == searchTerm;
      },
      orElse: () => {},
    );

    if (exactMatch.isNotEmpty) {
      dev.log('정확한 일치 발견: ${exactMatch['한글 종목명']}');
      // 실시간 데이터 가져오기
      final symbol = exactMatch['단축코드']?.toString();
      if (symbol != null) {
        dev.log('실시간 데이터 요청: $symbol');
        final realTimeData = await _fetchRealTimeStock(symbol);
        if (realTimeData != null) {
          dev.log('실시간 데이터 병합 완료');
          return {...exactMatch, ...realTimeData};
        } else {
          dev.log('실시간 데이터 가져오기 실패, 기본 데이터만 반환');
        }
      }
      return exactMatch;
    }

    dev.log('정확한 일치 없음, 부분 일치 검색 중...');
    final fallbackMatch = _mergedList!.firstWhere(
      (stock) {
        final name = stock['한글 종목명'].toString().toLowerCase();
        final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
        final searchTerm = q.toLowerCase();
        return name.contains(searchTerm) || shortName.contains(searchTerm);
      },
      orElse: () => {},
    );

    if (fallbackMatch.isNotEmpty) {
      dev.log('부분 일치 발견: ${fallbackMatch['한글 종목명']}');
      // 실시간 데이터 가져오기
      final symbol = fallbackMatch['단축코드']?.toString();
      if (symbol != null) {
        dev.log('실시간 데이터 요청: $symbol');
        final realTimeData = await _fetchRealTimeStock(symbol);
        if (realTimeData != null) {
          dev.log('실시간 데이터 병합 완료');
          return {...fallbackMatch, ...realTimeData};
        } else {
          dev.log('실시간 데이터 가져오기 실패, 기본 데이터만 반환');
        }
      }
      return fallbackMatch;
    }

    dev.log('검색 결과 없음');
    throw Exception('검색 결과 없음');
  }

  // ✅ 다중 결과 반환 (실시간 데이터 포함, 최대 50개)
  static Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    await _loadData();
    final q = keyword.trim();

    // 더 유연한 검색어 검증 (한글, 영문, 숫자, 공백 허용)
    final isValid = RegExp(r'^[가-힣a-zA-Z0-9\s]+$').hasMatch(q) && q.length >= 1;
    if (!isValid) throw Exception('검색어는 한글, 영문, 숫자만 입력 가능합니다.');

    // 먼저 로컬 데이터에서 검색 (대소문자 구분 없이, 한글 종목명과 한글 종목약명 모두 확인)
    final localMatches = _mergedList!.where((stock) {
      final name = stock['한글 종목명'].toString().toLowerCase();
      final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
      final searchTerm = q.toLowerCase();
      return name.contains(searchTerm) || shortName.contains(searchTerm);
    }).take(20).toList();

    // 전체 종목 API에서도 검색 (더 많은 결과)
    try {
      final baseUrl = Uri.base.origin;
      final url = '$baseUrl/api/krx-all-stocks?limit=50';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final allStocks = List<Map<String, dynamic>>.from(data['data']);
          final apiMatches = allStocks.where((stock) =>
            stock['name'].toString().contains(q) ||
            stock['symbol'].toString().contains(q)).take(30).toList();
          
          // 로컬 결과와 API 결과 병합
          final allMatches = [...localMatches, ...apiMatches];
          
          // 중복 제거 (symbol 기준)
          final uniqueMatches = <String, Map<String, dynamic>>{};
          for (final match in allMatches) {
            final symbol = match['symbol']?.toString() ?? match['단축코드']?.toString();
            if (symbol != null && !uniqueMatches.containsKey(symbol)) {
              uniqueMatches[symbol] = match;
            }
          }
          
          final results = uniqueMatches.values.take(50).toList();
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      }
    } catch (e) {
      dev.log('전체 종목 API 호출 실패, 로컬 데이터만 사용: $e');
    }

    // API 실패시 로컬 데이터만 사용
    if (localMatches.isEmpty) throw Exception('검색 결과 없음');

    // 실시간 데이터 병합 (병렬 처리)
    final List<Map<String, dynamic>> results = [];
    for (final match in localMatches) {
      final symbol = match['단축코드']?.toString();
      if (symbol != null) {
        final realTimeData = await _fetchRealTimeStock(symbol);
        if (realTimeData != null) {
          results.add({...match, ...realTimeData});
        } else {
          results.add(match);
        }
      } else {
        results.add(match);
      }
    }

    return results;
  }

  // 캐시 초기화 (새로고침 시 사용)
  static void clearCache() {
    _stockCache = null;
    _lastUpdate = null;
  }
}
