import 'dart:convert';
import 'package:http/http.dart' as http;

class KisStockService {
  static const String _appKey = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
  static const String _appSecret = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
  static const String _baseUrl = 'https://openapi.koreainvestment.com:9443';
  static const String _grantType = 'client_credentials';

  /// Access Token 요청
  static Future<String> _getAccessToken() async {
    final url = Uri.parse('$_baseUrl/oauth2/tokenP');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'grant_type': _grantType,
      'appkey': _appKey,
      'appsecret': _appSecret,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['access_token'];
    } else {
      throw Exception('토큰 발급 실패: ${response.body}');
    }
  }

  /// 키워드 기반 종목 검색 (예: "2차전지", "전기차" 등)
  static Future<List<String>> fetchStocks(String keyword) async {
    final accessToken = await _getAccessToken();

    final url = Uri.parse('$_baseUrl/uapi/domestic-stock/v1/quotations/inquire-search');
    final headers = {
      'Content-Type': 'application/json',
      'authorization': 'Bearer $accessToken',
      'appkey': _appKey,
      'appsecret': _appSecret,
      'tr_id': 'FHKST03010100', // 실전계좌 기준 종목 검색
    };
    final queryParams = {
      'word': keyword,
    };

    final uriWithParams = url.replace(queryParameters: queryParams);
    final response = await http.get(uriWithParams, headers: headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final items = json['output'] as List;

      return items
          .map((item) => '${item['hts_kor_isnm']} (${item['srtn_cd']})')
          .toList();
    } else {
      throw Exception('종목 조회 실패: ${response.body}');
    }
  }
}
