import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.get(Uri.parse('https://stockwiki.vercel.app/api/utils?type=commodity&symbol=GOLD'));
    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      if (result != null) {
        final meta = result['meta'];
        print('Meta: $meta');
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        print('Price: $price');
        if (price != null) {
           print('Success! Price is: ${price.toDouble()}');
        } else {
           print('Error: Price is null');
        }
      } else {
        print('Error: Result is null');
      }
    } else {
      print('HTTP Error: ${response.statusCode}');
    }
  } catch (e, stack) {
    print('Exception: $e');
    print(stack);
  }

  // BTC
  try {
    final response = await http.get(Uri.parse('https://stockwiki.vercel.app/api/utils?type=commodity&symbol=BTC'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      final price = result?['meta']?['regularMarketPrice'] ?? result?['meta']?['previousClose'];
      print('BTC Price: ${price?.toDouble()}');
    }
  } catch (e) {
    print('BTC Exception: $e');
  }
}
