import 'dart:convert';
import 'package:http/http.dart' as http;

class KisService {
  final String _proxyUrl = 'http://localhost:3000/kis-stock-info\apiservice-apiservice';

  Future<String> fetchStockInfo(String keyword) async {
  final isCode = RegExp(r'^\d{5,6}$').hasMatch(keyword);
  String code = keyword;

  // 종목명이면 먼저 검색 API 호출해서 종목번호 알아냄 
  if (!isCode) {
    final searchUri = Uri.parse('https://your-proxy-name.vercel.app/kis-stock-info?keyword=$keyword');
    final searchRes = await http.get(searchUri);
    if (searchRes.statusCode == 200) {
      final result = json.decode(searchRes.body);
      if (result.isNotEmpty) {
        code = result[0]['pdno']; // 종목번호
      } else {
        return '종목 검색 결과 없음';
      }
    } else {
      throw Exception('KIS 검색 API 호출 실패');
    }
  }

  // 이후 기존 방식대로 상세정보 API 호출
  final uri = Uri.parse('http://localhost:3000/kis-stock-info?code=$code');
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
    throw Exception('KIS API 호출 실패: ${response.statusCode}');
  }
}

}


