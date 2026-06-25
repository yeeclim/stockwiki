import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final res = await Supabase.instance.client.functions.invoke(
        'market-data',
        body: {'symbol': '^VIX'},
      );
      if (!mounted) return;
      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final meta = data['chart']?['result']?[0]?['meta'];
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
    } catch (_) {
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
