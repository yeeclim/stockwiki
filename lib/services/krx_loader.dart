import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class KrxLoader {
  static List<Map<String, dynamic>>? _mergedList;

  static Future<void> _loadData() async {
    if (_mergedList != null) return;
    final basicJson = await rootBundle.loadString('assets/data/krx_basic_info.json');
    final priceJson = await rootBundle.loadString('assets/data/krx_price_info.json');
    
    print("Json Length = ${basicJson.length}/${priceJson.length}");

    final List<dynamic> basicList = json.decode(basicJson);
    final List<dynamic> priceList = json.decode(priceJson);

    // price json은 영어로 되어있음
    final Map<String, dynamic> priceMap = {
      for (var item in priceList) item['name']: item
    };

    // basic json은 한글로 되어있음
    _mergedList = basicList.map<Map<String, dynamic>>((item) {
      final code = item['단축코드'];
      final matchedPrice = priceMap[code] ?? {};
      return {...item, ...matchedPrice};
    }).toList();
  }

  static Future<Map<String, dynamic>> searchStock(String keyword) async {
    await _loadData();
    final q = keyword.trim();
    final isValid = RegExp(r'^[가-힣0-9]+$').hasMatch(q);

    if (!isValid) {
      throw Exception('잘못된 검색어 형식입니다.');
    }


    final result = _mergedList!.where((stock) {
      if (isValid) {
        return (stock['한글 종목명'] ?? '').toString().contains(q);
      } else {
        return (stock['단축코드'] ?? '').toString().contains(q);
      }
    }).toList();

    if (result.isEmpty) throw Exception('검색 결과 없음');

    return result.first;
  }
}
