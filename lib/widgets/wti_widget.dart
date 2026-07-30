import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'market_data_card.dart';
import 'price_cache_mixin.dart';

class WtiWidget extends StatefulWidget {
  const WtiWidget({super.key});

  @override
  State<WtiWidget> createState() => _WtiWidgetState();
}

class _WtiWidgetState extends State<WtiWidget> with PriceCacheMixin {
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
    final cached = await loadCachedPrice('wti', const Duration(minutes: 10));
    if (cached != null && mounted) {
      setState(() {
        _wtiPrice = cached;
        _isLoading = false;
      });
    }
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
          await cachePrice('wti', _wtiPrice!);
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
