import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_utils.dart';
import 'market_data_card.dart';

class WtiWidget extends StatefulWidget {
  const WtiWidget({super.key});

  @override
  State<WtiWidget> createState() => _WtiWidgetState();
}

class _WtiWidgetState extends State<WtiWidget> {
  double? _wtiPrice;
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
      final cachedDate = prefs.getString('wti_date');
      final cacheTime = prefs.getInt('wti_cache_time');
      if (cachedPrice != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
                10 * 60 * 1000 &&
            (cachedDate == null || !cachedDate.contains('Fallback'))) {
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
      await prefs.setString('wti_date', 'Latest');
      await prefs.setInt(
          'wti_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchWtiPrice() async {
    try {
      final response = await http
          .get(Uri.parse('$webBaseUrl/api/utils?type=commodity&symbol=CL=F'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meta = data['chart']?['result']?[0]?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        if (price != null && (price as num) > 0) {
          if (!mounted) return;
          setState(() {
            _wtiPrice = price.toDouble();
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
      );
}
