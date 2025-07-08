import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UsdKrwWidget extends StatefulWidget {
  const UsdKrwWidget({super.key});

  @override
  State<UsdKrwWidget> createState() => _UsdKrwWidgetState();
}

class _UsdKrwWidgetState extends State<UsdKrwWidget> {
  double? _usdKrw;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsdKrw();
  }

  Future<void> _fetchUsdKrw() async {
    const apiKey = 'f1767aef0a23b6402850f3d9';
    final url = Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/latest/USD');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['conversion_rates']?['KRW'];

        if (rate != null && rate is num) {
          setState(() {
            _usdKrw = rate.toDouble();
            _isLoading = false;
          });
        } else {
          throw Exception('API 응답에 KRW 없음');
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
      color: Colors.blueGrey.shade900,
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
                        const Text('USD/KRW', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          '₩${_usdKrw!.toStringAsFixed(2)}',
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
