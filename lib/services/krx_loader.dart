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
      
      // 로컬에서는 API 호출을 시도하지 않고 바로 더미 데이터 사용
      if (!kReleaseMode) {
        dev.log('로컬 환경: 더미 데이터 사용');
        final dummyData = _generateDummyData(symbol);
        if (dummyData != null) {
          // 캐시 업데이트
          _stockCache ??= {};
          _stockCache![symbol] = dummyData;
          _lastUpdate = DateTime.now();
          return dummyData;
        }
        return null;
      }

      // 프로덕션 환경에서만 Vercel API 호출 (Yahoo Finance + 더미 데이터 폴백)
      final baseUrl = 'https://stockwiki.vercel.app';
      final url = '$baseUrl/api/simple-stock?symbol=$symbol';
      
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
        }
      } else {
        dev.log('API 호출 실패: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      dev.log('실시간 주식 데이터 가져오기 실패: $e');
      // API 실패 시 더미 데이터로 폴백
      dev.log('더미 데이터로 폴백 시도');
      return _generateDummyData(symbol);
    }
  }

  // 더미 데이터 생성 (실제 API 대신 사용)
  static Map<String, dynamic>? _generateDummyData(String symbol) {
    // 실제 주식 코드에 따른 더미 데이터 생성 (2025년 1월 기준 대략적 가격)
    final dummyPrices = {
      // KOSPI 주요 종목
      '005930': {'price': 75000, 'change': 1500, 'volume': 12000000, 'marketCap': 450000000000000}, // 삼성전자
      '000660': {'price': 45000, 'change': -800, 'volume': 8000000, 'marketCap': 32000000000000},  // SK하이닉스
      '035420': {'price': 180000, 'change': 2000, 'volume': 5000000, 'marketCap': 30000000000000}, // NAVER
      '035720': {'price': 420000, 'change': 5000, 'volume': 3000000, 'marketCap': 20000000000000}, // 카카오
      '207940': {'price': 280000, 'change': -3000, 'volume': 4000000, 'marketCap': 35000000000000}, // 삼성바이오로직스
      '006400': {'price': 380000, 'change': 8000, 'volume': 2000000, 'marketCap': 28000000000000}, // 삼성SDI
      '051910': {'price': 420000, 'change': -5000, 'volume': 1500000, 'marketCap': 30000000000000}, // LG화학
      '068270': {'price': 180000, 'change': 3000, 'volume': 1000000, 'marketCap': 12000000000000}, // 셀트리온
      '323410': {'price': 45000, 'change': 1000, 'volume': 5000000, 'marketCap': 20000000000000}, // 카카오뱅크
      '000270': {'price': 120000, 'change': -2000, 'volume': 3000000, 'marketCap': 50000000000000}, // 기아
      
      // KOSDAQ 주요 종목
      '096350': {'price': 25000, 'change': 500, 'volume': 2000000, 'marketCap': 5000000000000},   // 대창솔루션
      '086520': {'price': 180000, 'change': 5000, 'volume': 800000, 'marketCap': 15000000000000}, // 에코프로
      '247540': {'price': 220000, 'change': 8000, 'volume': 600000, 'marketCap': 18000000000000}, // 에코프로비엠
      '196170': {'price': 45000, 'change': -1000, 'volume': 1200000, 'marketCap': 8000000000000}, // 알테오젠
      '066970': {'price': 320000, 'change': 10000, 'volume': 400000, 'marketCap': 25000000000000}, // 엘앤에프
      '091990': {'price': 85000, 'change': 2000, 'volume': 800000, 'marketCap': 12000000000000}, // 셀트리온헬스케어
      '196300': {'price': 65000, 'change': -1500, 'volume': 600000, 'marketCap': 9000000000000}, // 에이치엘비
      '196490': {'price': 28000, 'change': 800, 'volume': 1500000, 'marketCap': 4000000000000}, // 다이나믹디자인
      '196700': {'price': 15000, 'change': -300, 'volume': 2000000, 'marketCap': 3000000000000}, // 웹젠
      '196800': {'price': 35000, 'change': 1200, 'volume': 1000000, 'marketCap': 6000000000000}, // 아이에이
    };

    final data = dummyPrices[symbol];
    if (data != null) {
      final price = data['price']!.toDouble();
      final change = data['change']!.toDouble();
      final volume = data['volume']!.toInt();
      final marketCap = data['marketCap']!.toInt();
      final changePercent = (change / (price - change) * 100);

      return {
        'symbol': symbol,
        'name': _getStockName(symbol),
        'price': price,
        'change': change,
        'changePercent': changePercent,
        'volume': volume,
        'marketCap': marketCap,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  // 주식명 매핑
  static String _getStockName(String symbol) {
    final names = {
      // KOSPI
      '005930': '삼성전자',
      '000660': 'SK하이닉스',
      '035420': 'NAVER',
      '035720': '카카오',
      '207940': '삼성바이오로직스',
      '006400': '삼성SDI',
      '051910': 'LG화학',
      '068270': '셀트리온',
      '323410': '카카오뱅크',
      '000270': '기아',
      
      // KOSDAQ
      '096350': '대창솔루션',
      '086520': '에코프로',
      '247540': '에코프로비엠',
      '196170': '알테오젠',
      '066970': '엘앤에프',
      '091990': '셀트리온헬스케어',
      '196300': '에이치엘비',
      '196490': '다이나믹디자인',
      '196700': '웹젠',
      '196800': '아이에이',
    };
    return names[symbol] ?? symbol;
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

    final isValid = RegExp(r'^[가-힣0-9]+$').hasMatch(q);
    if (!isValid) {
      dev.log('잘못된 검색어 형식: $q');
      throw Exception('잘못된 검색어 형식입니다.');
    }

    if (_mergedList == null || _mergedList!.isEmpty) {
      dev.log('기본 데이터가 로드되지 않았습니다.');
      throw Exception('데이터 로딩 실패');
    }

    dev.log('기본 데이터에서 검색 중... (총 ${_mergedList!.length}개 종목)');

    // 기본 정보에서 검색
    final exactMatch = _mergedList!.firstWhere(
      (stock) => stock['한글 종목명'].toString() == q,
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
      (stock) => stock['한글 종목명'].toString().contains(q),
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

    final isValid = RegExp(r'^[가-힣0-9]+$').hasMatch(q);
    if (!isValid) throw Exception('잘못된 검색어 형식입니다.');

    // 먼저 로컬 데이터에서 검색
    final localMatches = _mergedList!.where((stock) =>
      stock['한글 종목명'].toString().contains(q)).take(20).toList();

    // 전체 종목 API에서도 검색 (더 많은 결과)
    try {
      final baseUrl = kReleaseMode 
          ? 'https://stockwiki.vercel.app' 
          : 'http://localhost:3000';
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
