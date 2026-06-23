import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/exchange_rate_service.dart';
import '../utils/api_utils.dart';
import 'market_data_card.dart';

class GoldWidget extends StatefulWidget {
  const GoldWidget({super.key});

  @override
  State<GoldWidget> createState() => _GoldWidgetState();
}

class _GoldWidgetState extends State<GoldWidget> {
  double? _goldPrice;
  double? _usdKrwRate;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('gold_price');
      final cacheTime = prefs.getInt('gold_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime < 5 * 60 * 1000) {
          if (mounted)
            setState(() {
              _goldPrice = cachedPrice;
              _isLoading = false;
            });
        }
      }
    } catch (_) {}
  }

  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('gold_price', price);
      await prefs.setInt(
          'gold_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchGoldPrice() async {
    try {
      final response = await http
          .get(Uri.parse('$webBaseUrl/api/utils?type=commodity&symbol=GOLD'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meta = data['chart']?['result']?[0]?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        if (price != null) {
          if (!mounted) return;
          setState(() {
            _goldPrice = (price as num).toDouble();
            _isLoading = false;
          });
          await _cachePrice(_goldPrice!);
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
    );
  }
}
