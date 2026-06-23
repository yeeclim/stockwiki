import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_utils.dart';
import 'market_data_card.dart';

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
    _loadCachedPrice();
    _fetchPrice();
  }

  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('btc_price');
      final cacheTime = prefs.getInt('btc_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime < 5 * 60 * 1000) {
          if (mounted)
            setState(() {
              _btcPrice = cachedPrice;
              _isLoading = false;
            });
        }
      }
    } catch (_) {}
  }

  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('btc_price', price);
      await prefs.setInt(
          'btc_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchPrice() async {
    try {
      final res = await http
          .get(Uri.parse('$webBaseUrl/api/utils?type=commodity&symbol=BTC'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final meta = data['chart']?['result']?[0]?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        if (price != null) {
          if (!mounted) return;
          setState(() {
            _btcPrice = (price as num).toDouble();
            _isLoading = false;
          });
          await _cachePrice(_btcPrice!);
          return;
        }
      }
      throw Exception('데이터 없음');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터 로드 실패';
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
        valueText: '\$${_btcPrice?.toStringAsFixed(2) ?? 'N/A'}',
        subText: 'USD',
      );
}
