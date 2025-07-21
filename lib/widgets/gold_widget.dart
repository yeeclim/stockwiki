import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoldWidget extends StatefulWidget {
  const GoldWidget({super.key});

  @override
  State<GoldWidget> createState() => _GoldWidgetState();
}

class _GoldWidgetState extends State<GoldWidget> {
  double? _goldPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGoldPrice();
  }

  Future<void> _fetchGoldPrice() async {
    try {
      final uri = Uri.parse(
        'https://api.twelvedata.com/price?symbol=XAU/USD&apikey=105c740ebca44e2ba687cfe806fa6b98',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['price'] != null) {
          setState(() {
            _goldPrice = double.tryParse(data['price']);
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? '데이터 오류');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 80,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Gold (XAU/USD)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          _goldPrice != null
                              ? '\$${_goldPrice!.toStringAsFixed(2)} / oz'
                              : '데이터 없음',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
