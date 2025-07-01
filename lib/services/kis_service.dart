import 'dart:convert';
import 'package:http/http.dart' as http;

class KisService {
  final String _proxyUrl =
      'https://stockwiki-gw35etj6o-bermonts-projects.vercel.app/kis-stock-info';

  Future<String> fetchStockInfo(String keyword) async {
    final isCode = RegExp(r'^\d{5,6}$').hasMatch(keyword);
    String code = keyword;

    if (!isCode) {
      final searchUri = Uri.parse('$_proxyUrl?pdno=$code');
      final searchRes = await http.get(searchUri);

      if (searchRes.statusCode == 200) {
        final result = json.decode(searchRes.body);
        if (result.isNotEmpty) {
          code = result[0]['pdno']; // 종목코드 추출
        } else {
          return '종목 검색 결과 없음';
        }
      } else {
        throw Exception('KIS 종목 검색 API 호출 실패');
      }
    }

    final uri = Uri.parse('$_proxyUrl?code=$code');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final output = data['output'];

      if (output == null || output is! Map) return '검색 결과 없음';

      final name = output['prdt_abrv_name'] ?? '이름없음';
      final pdno = output['pdno'] ?? '코드없음';
      final price = output['stck_prpr'] ?? 'N/A';

      return '$name ($pdno) - ₩$price';
    } else {
      throw Exception('KIS 상세정보 API 호출 실패: ${response.statusCode}');
    }
  }
}
