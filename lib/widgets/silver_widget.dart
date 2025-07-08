import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SilverWidget extends StatefulWidget {
  const SilverWidget({super.key});

  @override
  State<SilverWidget> createState() => _SilverWidgetState();
}

class _SilverWidgetState extends State<SilverWidget> {
  double? _silverPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSilverPrice();
  }

  Future<void> _fetchSilverPrice() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.metalpriceapi.com/v1/latest?api_key=ed91a84eac666be02a62adf79c5a23b2&base=USD&currencies=XAG',
      ));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final price = data['rates']['USDXAG'];
        setState(() {
          _silverPrice = price.toDouble();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load silver price');
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
      color: Colors.grey.shade800,
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
                          'Silver (USDXAG)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '\$${_silverPrice!.toStringAsFixed(2)} / oz',
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
