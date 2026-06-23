import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/exchange_rate_service.dart';
import '../utils/api_utils.dart';
import 'market_data_card.dart';

class SilverWidget extends StatefulWidget {
  const SilverWidget({super.key});

  @override
  State<SilverWidget> createState() => _SilverWidgetState();
}

class _SilverWidgetState extends State<SilverWidget> {
  double? _silverPrice;
  double? _usdKrwRate;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchSilverPrice();
    _fetchExchangeRate();
  }

  Future<void> _fetchExchangeRate() async {
    final rate = await ExchangeRateService.getUsdToKrw();
    if (mounted) setState(() => _usdKrwRate = rate);
  }

  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('silver_price');
      final cacheTime = prefs.getInt('silver_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            10 * 60 * 1000) {
          if (mounted)
            setState(() {
              _silverPrice = cachedPrice;
              _isLoading = false;
            });
        }
      }
    } catch (_) {}
  }

  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('silver_price', price);
      await prefs.setInt(
          'silver_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchSilverPrice() async {
    final symbols = ['SI=F', 'XAGUSD=X'];
    for (final symbol in symbols) {
      try {
        final response = await http
            .get(Uri.parse(
                '$webBaseUrl/api/utils?type=commodity&symbol=$symbol'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final meta = data['chart']?['result']?[0]?['meta'];
          final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
          if (price != null && (price as num) > 0) {
            if (!mounted) return;
            setState(() {
              _silverPrice = price.toDouble();
              _isLoading = false;
            });
            await _cachePrice(_silverPrice!);
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
    if (_silverPrice != null && _usdKrwRate != null && _usdKrwRate! > 0) {
      final krwPerDon = _silverPrice! * _usdKrwRate! * ozToDon;
      subText = '약 ${krwPerDon.toStringAsFixed(0)}원 / 돈';
    }

    return MarketDataCard(
      accentColor: Colors.blueGrey,
      headerIcon: const Text('Ag',
          style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
      title: 'Silver',
      isLoading: _isLoading,
      error: _error,
      valueText: _silverPrice != null
          ? '\$${_silverPrice!.toStringAsFixed(2)}'
          : 'N/A',
      subText: subText,
    );
  }
}
