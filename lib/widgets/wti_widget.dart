import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WtiWidget extends StatefulWidget {
  const WtiWidget({super.key});

  @override
  State<WtiWidget> createState() => _WtiWidgetState();
}

class _WtiWidgetState extends State<WtiWidget> {
  double? _wtiPrice;
  String? _date;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWtiPrice();
  }

  Future<void> _fetchWtiPrice() async {
    const apiKey = '4X0kMGDGQo7wdJ0BAtVJ3PygI15g8GdiVQsCpeGt';
    const url = 'https://api.eia.gov/v2/seriesid/PET.RWTC.D?api_key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latest = data['response']['data'][0];

        setState(() {
          _wtiPrice = latest['value']?.toDouble();
          _date = latest['period'];
          _isLoading = false;
        });
      } else {
        throw Exception('응답 코드: ${response.statusCode}');
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
      color: Colors.teal.shade700,
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
                          'WTI 유가 (USD/bbl)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          _wtiPrice != null ? '\$${_wtiPrice!.toStringAsFixed(2)}' : 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_date != null)
                          Text(
                            _date!,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}
