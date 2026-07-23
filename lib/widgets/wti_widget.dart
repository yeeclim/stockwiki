import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'market_data_card.dart';

class WtiWidget extends StatefulWidget {
  const WtiWidget({super.key});

  @override
  State<WtiWidget> createState() => _WtiWidgetState();
}

class _WtiWidgetState extends State<WtiWidget> {
  double? _wtiPrice;
  double? _changePercent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchWtiPrice();
  }

  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('wti_price');
      final cacheTime = prefs.getInt('wti_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            10 * 60 * 1000) {
          if (mounted)
            setState(() {
              _wtiPrice = cachedPrice;
              _isLoading = false;
            });
        }
      }
    } catch (_) {}
  }

  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wti_price', price);
      await prefs.setInt(
          'wti_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchWtiPrice() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'market-data',
        body: {'symbol': 'CL=F'},
      );
      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final meta = data['chart']?['result']?[0]?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        final prevClose = meta?['previousClose'];
        if (price != null && (price as num) > 0) {
          if (!mounted) return;
          setState(() {
            _wtiPrice = price.toDouble();
            if (prevClose != null && (prevClose as num) > 0) {
              _changePercent = (_wtiPrice! - prevClose.toDouble()) /
                  prevClose.toDouble() *
                  100;
            }
            _isLoading = false;
          });
          await _cachePrice(_wtiPrice!);
          return;
        }
      }
      throw Exception('데이터 없음');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MarketDataCard(
        accentColor: Colors.teal,
        headerIcon: const Icon(Icons.opacity, color: Colors.teal, size: 16),
        title: 'WTI 유가',
        isLoading: _isLoading,
        error: _error,
        valueText:
            _wtiPrice != null ? '\$${_wtiPrice!.toStringAsFixed(2)}' : 'N/A',
        changePercent: _changePercent,
      );
}
