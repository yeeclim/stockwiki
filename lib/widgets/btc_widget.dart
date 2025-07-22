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
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 80),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.red))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'BTC/USD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_btcPrice?.toStringAsFixed(2) ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
