import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OilWidget extends StatefulWidget {
  const OilWidget({super.key});

  @override
  State<OilWidget> createState() => _OilWidgetState();
}

class _OilWidgetState extends State<OilWidget> {
  double? _oilPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOilPrice();
  }

  Future<void> _fetchOilPrice() async {
    try {
      final response = await http.get(Uri.parse('https://api.api-ninjas.com/v1/commodities?name=crude_oil'), headers: {
        'X-Api-Key': 'YOUR_API_KEY_HERE'
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _oilPrice = data[0]['price'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load oil price');
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
    return SizedBox(
      height: 60,
      child: Card(
        color: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'WTI Crude Oil',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      _error ?? '\$${_oilPrice!.toStringAsFixed(2)} / barrel',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
