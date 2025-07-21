// 📄 lib/widgets/vix_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VixWidget extends StatefulWidget {
  const VixWidget({super.key});

  @override
  State<VixWidget> createState() => _VixWidgetState();
}

class _VixWidgetState extends State<VixWidget> {
  double? _vixValue;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVix();
  }

  Future<void> _fetchVix() async {
    try {
      final response = await http.get(
        Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/^VIX?interval=1d&range=1d'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final price = data['chart']['result'][0]['meta']['regularMarketPrice'];
        setState(() {
          _vixValue = price.toDouble();
          _isLoading = false;
        });
      } else {
        throw Exception('Yahoo 응답 오류');
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
      color: Colors.deepPurple.shade400,
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
                        const Text('VIX (변동성지수)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          _vixValue?.toStringAsFixed(2) ?? '',
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
