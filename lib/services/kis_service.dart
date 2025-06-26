import 'dart:convert';
import 'package:http/http.dart' as http;

class KisService {
  final String _proxyUrl = 'http://localhost:3000/kis-stock-info';

  Future<String> fetchStockInfo(String code) async {
    final uri = Uri.parse('$_proxyUrl?code=$code');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // 응답 형태에 따라 유연하게 파싱
      final output = data['output'];
      if (output == null || output is! Map) {
        return '검색 결과 없음';
      }

      final name = output['prdt_abrv_name'] ?? '이름없음';
      final pdno = output['pdno'] ?? '코드없음';
      final price = output['stck_prpr'] ?? 'N/A';

      return '$name ($pdno) - ₩$price';
    } else {
      throw Exception('KIS API 호출 실패: ${response.statusCode}');
    }
  }
}


