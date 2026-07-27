import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'gauge_card.dart';

/// 암호화폐(비트코인) 시장 심리 — alternative.me Crypto Fear & Greed Index.
/// 주의: CNN의 주식시장용 Fear & Greed Index와는 다른 별개의 지표다.
/// 주식시장 심리는 [StockFearGreedWidget](VIX 기준)을 참고할 것.
class FearGreedWidget extends StatefulWidget {
  const FearGreedWidget({super.key});

  @override
  State<FearGreedWidget> createState() => _FearGreedWidgetState();
}

class _FearGreedWidgetState extends State<FearGreedWidget> {
  int? _indexValue;
  String? _label;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedIndex();
    _fetchIndex();
  }

  Future<void> _loadCachedIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedValue = prefs.getInt('fear_greed_value');
      final cachedLabel = prefs.getString('fear_greed_label');
      final cacheTime = prefs.getInt('fear_greed_cache_time');
      if (cachedValue != null && cachedLabel != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            30 * 60 * 1000) {
          if (mounted) {
            setState(() {
              _indexValue = cachedValue;
              _label = cachedLabel;
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheIndex(int value, String label) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fear_greed_value', value);
      await prefs.setString('fear_greed_label', label);
      await prefs.setInt(
          'fear_greed_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchIndex() async {
    try {
      // api.alternative.me — 암호화폐(비트코인) 전용 공포탐욕지수, 무료 공개 API
      final response = await http
          .get(Uri.parse('https://api.alternative.me/fng/?limit=1'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final item = data['data']?[0];
        if (item != null) {
          final value = int.tryParse(item['value']?.toString() ?? '');
          final label =
              _translateLabel(item['value_classification']?.toString() ?? '');
          if (value != null && !mounted) return;
          if (value != null) {
            setState(() {
              _indexValue = value;
              _label = label;
              _isLoading = false;
            });
            await _cacheIndex(value, label);
            return;
          }
        }
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  String _translateLabel(String label) {
    switch (label.toLowerCase()) {
      case 'extreme fear':
        return '극도의 공포';
      case 'fear':
        return '공포';
      case 'neutral':
        return '중립';
      case 'greed':
        return '탐욕';
      case 'extreme greed':
        return '극도의 탐욕';
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GaugeCard(
      isLoading: _isLoading,
      error: _error,
      value: _indexValue ?? 0,
      title: '암호화폐 공포탐욕지수 · ${_label ?? ''}',
      subtitle: '비트코인 시장 심리 · 0(극도의 공포) ~ 100(극도의 탐욕)',
    );
  }
}
