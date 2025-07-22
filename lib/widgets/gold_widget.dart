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
    // 고정 환율 사용 또는 외부에서 주입 가능
    const double krwPerUsd = 1383.66; // USD to KRW
    const double ozToDon = 1 / 7.5599; // 1 oz = 7.5599 돈

    double? krwPerDon;
    if (_goldPrice != null) {
      krwPerDon = _goldPrice! * krwPerUsd * ozToDon;
    }

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
                          '\$${_goldPrice!.toStringAsFixed(2)} / oz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (krwPerDon != null)
                          Text(
                            '약 ${krwPerDon.toStringAsFixed(0)} KRW / 돈',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}