import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/cache_service.dart';
import '../utils/number_format_utils.dart';
import 'market_data_card.dart';

class BtcWidget extends StatefulWidget {
  const BtcWidget({super.key});

  @override
  State<BtcWidget> createState() => _BtcWidgetState();
}

class _BtcWidgetState extends State<BtcWidget> {
  static const _cacheKey = 'btc_price';

  double? _btcPrice;
  double? _changePercent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchPrice();
  }

  Future<void> _loadCachedPrice() async {
    final cached = await CacheService.get(_cacheKey);
    if (cached is num && mounted) {
      setState(() {
        _btcPrice = cached.toDouble();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPrice() async {
    try {
      // CoinGecko — 무료 공개 API, CORS 지원, API 키 불필요
      final res = await http
          .get(Uri.parse(
              'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final price = data['bitcoin']?['usd'];
        final change = data['bitcoin']?['usd_24h_change'];
        if (price != null) {
          if (!mounted) return;
          setState(() {
            _btcPrice = (price as num).toDouble();
            if (change != null) _changePercent = (change as num).toDouble();
            _isLoading = false;
          });
          await CacheService.set(_cacheKey, _btcPrice!,
              expiration: const Duration(minutes: 5));
          return;
        }
      }
      throw Exception('데이터 없음');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_btcPrice == null) _error = '데이터 로드 실패';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MarketDataCard(
        accentColor: Colors.orange,
        headerIcon:
            const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 16),
        title: 'Bitcoin',
        isLoading: _isLoading,
        error: _error,
        valueText: _btcPrice != null
            ? '\$${formatWithCommas(_btcPrice!, decimals: 2)}'
            : 'N/A',
        subText: 'USD',
        changePercent: _changePercent,
      );
}
