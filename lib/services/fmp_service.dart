import 'dart:convert';
import 'dart:developer'; // ← 이 줄 추가
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class FMPService {
  static const String _apiKey = '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh'; // 실제 키로 교체
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';

  /// 키워드 기반 검색 후 실시간 가격 정보 추가
  static Future<List<Stock>> fetchStocks(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final searchUrl = Uri.parse(
        '$_baseUrl/search?query=$keyword&limit=10&exchange=NASDAQ&apikey=$_apiKey&t=$timestamp',
      );
      final searchRes = await http.get(searchUrl, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });

      if (searchRes.statusCode != 200) throw Exception('검색 실패');

      final searchData = json.decode(searchRes.body);
      if (searchData is! List || searchData.isEmpty) return [];

      List<String> symbols = searchData
          .map<String>((e) => e['symbol'] as String)
          .toList();

      // 심볼 기반으로 실시간 정보 조회
      final quoteUrl = Uri.parse(
        '$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp',
      );
      final quoteRes = await http.get(quoteUrl, headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });

      if (quoteRes.statusCode != 200) throw Exception('시세 조회 실패');

      final quoteData = json.decode(quoteRes.body);
      if (quoteData is! List) return [];

      List<Stock> stocks = quoteData
          .map<Stock>((item) => Stock.fromJson(item))
          .toList();

      return stocks;
    } catch (e) {
      log('Error fetching stocks: $e'); // print 대신 log 사용
      return [];
    }
  }
}
