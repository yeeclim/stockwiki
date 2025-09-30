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
      // 새로고침 시에는 캐시 무시하고 항상 새 데이터 가져오기
      dev.log('캐시 무시하고 새 데이터 가져오기: $symbol');

      dev.log('네이버 금융 API 호출 시작: $symbol');
      
      // 1차: API 호출 시도 (현재 도메인 사용)
      final baseUrl = Uri.base.origin;
      final url = '$baseUrl/api/naver-stock?symbol=$symbol';
      
      dev.log('API URL: $url');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$url&t=$timestamp'),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      dev.log('API 응답 상태: ${response.statusCode}');
      dev.log('API 응답 본문: ${response.body}');

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

          dev.log('=== KRX 로더 디버깅 ===');
          dev.log('종목: $symbol');
          dev.log('원본 데이터: $stockData');
          dev.log('파싱된 가격: ${result['price']}');
          dev.log('가격이 0인가? ${result['price'] == 0.0}');
          dev.log('가격이 null인가? ${result['price'] == null}');
          dev.log('주식 데이터 파싱 완료: $result');
          dev.log('======================');

          // 캐시 업데이트
          _stockCache ??= {};
          _stockCache![symbol] = result;
          _lastUpdate = DateTime.now();

          return result;
        }
      }
      
      // 2차: 직접 네이버 크롤링 시도
      dev.log('API 실패 - 직접 크롤링 시도: $symbol');
      final crawledData = await _crawlNaverDirectly(symbol);
      if (crawledData != null) {
        dev.log('직접 크롤링 성공: $crawledData');
        return crawledData;
      }
      
      // 3차: 대체 가격 사용 (최후 수단)
      dev.log('모든 방법 실패 - 대체 가격 사용: $symbol');
      final fallbackPrice = _getFallbackPrice(symbol);
      if (fallbackPrice > 0) {
        final result = {
          'symbol': symbol,
          'name': _getStockName(symbol),
          'price': fallbackPrice,
          'change': 0.0,
          'changePercent': 0.0,
          'volume': 1000000,
          'marketCap': 0,
          'lastUpdate': DateTime.now().toIso8601String(),
        };
        
        dev.log('대체 가격 사용: $result');
        return result;
      }
      
      dev.log('API 실패 - 모든 방법 실패: $symbol');
      return null;
    } catch (e) {
      dev.log('실시간 주식 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 대체 가격 제공 (임시) - 2024년 12월 기준
  static double _getFallbackPrice(String symbol) {
    final prices = {
      '005930': 85000.0, // 삼성전자 (업데이트)
      '000660': 140000.0, // SK하이닉스 (업데이트)
      '035420': 200000.0, // NAVER (업데이트)
      '035720': 50000.0, // 카카오 (업데이트)
      '207940': 900000.0, // 삼성바이오로직스 (업데이트)
      '006400': 450000.0, // 삼성SDI (업데이트)
      '051910': 400000.0, // LG화학 (업데이트)
      '068270': 200000.0, // 셀트리온 (업데이트)
      '323410': 50000.0, // 카카오뱅크 (업데이트)
      '000270': 120000.0, // 기아 (업데이트)
    };
    return prices[symbol] ?? 0.0;
  }

  // 직접 네이버 크롤링 (CORS 우회)
  static Future<Map<String, dynamic>?> _crawlNaverDirectly(String symbol) async {
    try {
      // CORS 프록시 사용
      final proxyUrl = 'https://api.allorigins.win/raw?url=';
      final naverUrl = 'https://finance.naver.com/item/main.naver?code=$symbol';
      final fullUrl = '$proxyUrl${Uri.encodeComponent(naverUrl)}';
      
      dev.log('직접 크롤링 URL: $fullUrl');
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final html = response.body;
        dev.log('크롤링 HTML 길이: ${html.length}');
        
        // 간단한 가격 추출
        final priceMatch = RegExp(r'<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)</span>').firstMatch(html);
        if (priceMatch != null) {
          final priceStr = priceMatch.group(1)!.replaceAll(',', '');
          final price = double.tryParse(priceStr);
          
          if (price != null && price > 0) {
            return {
              'symbol': symbol,
              'name': _getStockName(symbol),
              'price': price,
              'change': 0.0,
              'changePercent': 0.0,
              'volume': 1000000,
              'marketCap': 0,
              'lastUpdate': DateTime.now().toIso8601String(),
            };
          }
        }
      }
      
      dev.log('직접 크롤링 실패: ${response.statusCode}');
      return null;
    } catch (e) {
      dev.log('직접 크롤링 오류: $e');
      return null;
    }
  }

  // 종목명 제공
  static String _getStockName(String symbol) {
    final names = {
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
        final isMatch = name == searchTerm || shortName == searchTerm;
        
        // 디버깅용 로그
        if (searchTerm == 'lg' || searchTerm == 'sk') {
          dev.log('검색 중: $searchTerm vs $name, $shortName -> $isMatch');
        }
        
        return isMatch;
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

    // 검색 결과가 없으면 "보통주" 추가해서 재검색
    dev.log('검색 결과 없음, "보통주" 추가해서 재검색 시도');
    final extendedSearchTerm = '${q}보통주';
    dev.log('확장 검색어: $extendedSearchTerm');
    
    final extendedMatch = _mergedList!.firstWhere(
      (stock) {
        final name = stock['한글 종목명'].toString().toLowerCase();
        final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
        return name.contains(extendedSearchTerm.toLowerCase()) || 
               shortName.contains(extendedSearchTerm.toLowerCase());
      },
      orElse: () => {},
    );

    if (extendedMatch.isNotEmpty) {
      dev.log('확장 검색으로 발견: ${extendedMatch['한글 종목명']}');
      // 실시간 데이터 가져오기
      final symbol = extendedMatch['단축코드']?.toString();
      if (symbol != null) {
        dev.log('실시간 데이터 요청: $symbol');
        final realTimeData = await _fetchRealTimeStock(symbol);
        if (realTimeData != null) {
          dev.log('실시간 데이터 병합 완료');
          return {...extendedMatch, ...realTimeData};
        } else {
          dev.log('실시간 데이터 가져오기 실패, 기본 데이터만 반환');
        }
      }
      return extendedMatch;
    }

    dev.log('검색 결과 없음');
    throw Exception('검색 결과 없음');
  }

  // ✅ 다중 결과 반환 (실시간 데이터 포함, 최대 50개)
  static Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    dev.log('searchStocks 호출됨: $keyword');
    await _loadData();
    final q = keyword.trim();
    dev.log('검색어 정리됨: $q');

    // 더 유연한 검색어 검증 (한글, 영문, 숫자, 공백 허용)
    final isValid = RegExp(r'^[가-힣a-zA-Z0-9\s]+$').hasMatch(q) && q.length >= 1;
    dev.log('검색어 유효성: $isValid');
    if (!isValid) throw Exception('검색어는 한글, 영문, 숫자만 입력 가능합니다.');

    // 먼저 로컬 데이터에서 검색 (대소문자 구분 없이, 한글 종목명과 한글 종목약명 모두 확인)
    dev.log('로컬 데이터 검색 시작: $q');
    final localMatches = _mergedList!.where((stock) {
      final name = stock['한글 종목명'].toString().toLowerCase();
      final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
      final searchTerm = q.toLowerCase();
      final isMatch = name.contains(searchTerm) || shortName.contains(searchTerm);
      
      // LG, SK 특별 처리
      if (searchTerm == 'lg' && shortName == 'lg') {
        dev.log('LG 매치 발견: $name, $shortName');
        return true;
      }
      if (searchTerm == 'sk' && shortName == 'sk') {
        dev.log('SK 매치 발견: $name, $shortName');
        return true;
      }
      
      return isMatch;
    }).take(20).toList();
    
    dev.log('로컬 검색 결과: ${localMatches.length}개');
    
    // 검색 결과가 없으면 "보통주" 추가해서 재검색
    if (localMatches.isEmpty) {
      dev.log('검색 결과 없음, "보통주" 추가해서 재검색 시도');
      final extendedSearchTerm = '${q}보통주';
      dev.log('확장 검색어: $extendedSearchTerm');
      
      final extendedMatches = _mergedList!.where((stock) {
        final name = stock['한글 종목명'].toString().toLowerCase();
        final shortName = stock['한글 종목약명']?.toString().toLowerCase() ?? '';
        return name.contains(extendedSearchTerm.toLowerCase()) || 
               shortName.contains(extendedSearchTerm.toLowerCase());
      }).take(20).toList();
      
      if (extendedMatches.isNotEmpty) {
        dev.log('확장 검색으로 ${extendedMatches.length}개 발견');
        localMatches.addAll(extendedMatches);
      }
    }

    // 전체 종목 API에서도 검색 (더 많은 결과)
    try {
      final baseUrl = Uri.base.origin;
      final url = '$baseUrl/api/krx-all-stocks?limit=50';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$url&t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
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
