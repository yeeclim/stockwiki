import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_utils.dart';

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
      // CORS 우회를 위해 자체 서버 프록시를 사용합니다 (Yahoo Finance 직접 호출 금지).
      final uri = Uri.parse(webBaseUrl).replace(
        path: '/api/utils',
        queryParameters: {'type': 'commodity', 'symbol': '^VIX'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        final meta = result?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        if (price != null) {
          setState(() {
            _vixValue = (price as num).toDouble();
            _isLoading = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '에러 발생';
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
              ? const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)
              : _error != null
                  ? Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('VIX (변동성지수)',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
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
