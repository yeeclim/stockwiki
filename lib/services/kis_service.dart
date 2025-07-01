import 'dart:convert';
import 'package:http/http.dart' as http;

class KisService {
  final String _baseUrl = 'https://stockwiki.vercel.app/api/kis-stock-info';

  Future<Map<String, dynamic>> fetchStockInfo(String code) async {
    final uri = Uri.parse('$_baseUrl?code=$code');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final output = data['output'];
      if (output is Map<String, dynamic>) {
        return output;
      } else {
        throw Exception('output 파싱 실패');
      }
    } else {
      throw Exception('KIS API 실패 (${response.statusCode})');
    }
  }
}
