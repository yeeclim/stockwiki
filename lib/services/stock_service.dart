import 'fmp_service.dart';
import 'kis_service.dart';
import '../models/stock.dart';

class StockService {
  static Future<List<Stock>> fetchStocks(String keyword) async {
  print('검색 키워드: $keyword');
  final url = Uri.parse(
    '$_baseUrl/search?query=$keyword&limit=20&exchange=NASDAQ,NYSE,AMEX&apikey=$_apiKey',
  );

  try {
    final response = await http.get(url);
    print('응답코드: ${response.statusCode}');
    print('응답데이터: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Stock(
        symbol: e['symbol'] ?? '',
        name: e['name'] ?? '',
        price: 0.0,
      )).toList();
    } else {
      print('에러 응답: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('예외 발생: $e');
    return [];
  }
}

}
