import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/exchange_rate_service.dart';
import 'market_data_card.dart';
import 'price_cache_mixin.dart';

class GoldWidget extends StatefulWidget {
  const GoldWidget({super.key});

  @override
  State<GoldWidget> createState() => _GoldWidgetState();
}

class _GoldWidgetState extends State<GoldWidget> with PriceCacheMixin {
  double? _goldPrice;
  double? _usdKrwRate;
  double? _changePercent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchGoldPrice();
    _fetchExchangeRate();
  }

  Future<void> _fetchExchangeRate() async {
    final rate = await ExchangeRateService.getUsdToKrw();
    if (mounted) setState(() => _usdKrwRate = rate);
  }

  Future<void> _loadCachedPrice() async {
    final cached = await loadCachedPrice('gold', const Duration(minutes: 5));
    if (cached != null && mounted) {
      setState(() {
        _goldPrice = cached;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGoldPrice() async {
    for (final symbol in ['GC=F', 'XAUUSD=X']) {
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'market-data',
          body: {'symbol': symbol},
        );
        if (res.status == 200 && res.data != null) {
          final data = res.data as Map<String, dynamic>;
          final meta = data['chart']?['result']?[0]?['meta'];
          final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
          final prevClose = meta?['previousClose'];
          if (price != null && (price as num) > 0) {
            if (!mounted) return;
            setState(() {
              _goldPrice = price.toDouble();
              if (prevClose != null && (prevClose as num) > 0) {
                _changePercent = (_goldPrice! - prevClose.toDouble()) /
                    prevClose.toDouble() *
                    100;
              }
              _isLoading = false;
            });
            await cachePrice('gold', _goldPrice!);
            return;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const ozToDon = 1 / 7.5599;
    String? subText;
    if (_goldPrice != null && _usdKrwRate != null && _usdKrwRate! > 0) {
      final krwPerDon = _goldPrice! * _usdKrwRate! * ozToDon;
      subText = '약 ${krwPerDon.toStringAsFixed(0)}원 / 돈';
    }

    return MarketDataCard(
      accentColor: Colors.amber,
      headerIcon: const Text('Au',
          style: TextStyle(
              color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
      title: 'Gold',
      isLoading: _isLoading,
      error: _error,
      valueText:
          _goldPrice != null ? '\$${_goldPrice!.toStringAsFixed(2)}' : 'N/A',
      subText: subText,
      changePercent: _changePercent,
    );
  }
}
