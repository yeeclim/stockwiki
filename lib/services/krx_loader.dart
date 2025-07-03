import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;

class KrxLoader {
  static List<Map<String, dynamic>>? _mergedList;

  // JSON 데이터를 한 번만 불러오고 병합
  static Future<void> _loadData() async {
    if (_mergedList != null) return;

    final basicRes = await http.get(Uri.base.resolve('assets/krx_basic_info.json'));
    final priceRes = await http.get(Uri.base.resolve('assets/krx_price_info.json'));

    final basicJson = utf8.decode(basicRes.bodyBytes);
    final priceJson = utf8.decode(priceRes.bodyBytes);

    final basicList = json.decode(basicJson) as List;
    final priceList = json.decode(priceJson) as List;

    final Map<String, dynamic> priceMap = {
      for (var item in priceList) item['code'].toString(): item,
    };

    _mergedList = basicList.map<Map<String, dynamic>>((item) {
      final code = item['단축코드']?.toString() ?? item['code']?.toString();
      final matchedPrice = priceMap[code] ?? {};
      return {...item, ...matchedPrice};
    }).toList();
  }

  // ✅ 단일 결과 반환 (가장 정확히 일치하는 종목 1개만)
  static Future<Map<String, dynamic>> searchStock(String keyword) async {
    await _loadData();
    final q = keyword.trim();

    final isValid = RegExp(r'^[가-힣0-9]+$').hasMatch(q);
    if (!isValid) throw Exception('잘못된 검색어 형식입니다.');

    final exactMatch = _mergedList!.firstWhere(
      (stock) => stock['한글 종목명'].toString() == q,
      orElse: () => {},
    );

    if (exactMatch.isNotEmpty) return exactMatch;

    final fallbackMatch = _mergedList!.firstWhere(
      (stock) => stock['한글 종목명'].toString().contains(q),
      orElse: () => {},
    );

    if (fallbackMatch.isNotEmpty) return fallbackMatch;

    throw Exception('검색 결과 없음');
  }

  // ✅ 다중 결과 반환 (ListView 등으로 표시할 때 사용)
  static Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    await _loadData();
    final q = keyword.trim();

    final isValid = RegExp(r'^[가-힣0-9]+$').hasMatch(q);
    if (!isValid) throw Exception('잘못된 검색어 형식입니다.');

    final matches = _mergedList!.where((stock) =>
      stock['한글 종목명'].toString().contains(q)).toList();

    if (matches.isEmpty) throw Exception('검색 결과 없음');

    return matches;
  }
}
