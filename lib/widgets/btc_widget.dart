import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BtcWidget extends StatefulWidget {
  const BtcWidget({super.key});

  @override
  State<BtcWidget> createState() => _BtcWidgetState();
}

class _BtcWidgetState extends State<BtcWidget> {
  double? _btcPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPrice();
  }

  Future<void> _fetchPrice() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _btcPrice = data['bitcoin']['usd']?.toDouble();
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = '에러: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 80,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('BTC/USD',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_btcPrice?.toStringAsFixed(2) ?? 'N/A'}',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
