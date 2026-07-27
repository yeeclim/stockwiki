import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'gauge_card.dart';

/// 주식시장 심리 — CNN Business의 실제 Fear & Greed Index.
/// api/fear-greed.js가 CNN의 비공식 데이터 엔드포인트를 그대로 프록시하므로
/// CNN 웹페이지에 나오는 수치와 동일하다(약식 근사치가 아님).
class StockFearGreedWidget extends StatefulWidget {
  const StockFearGreedWidget({super.key});

  @override
  State<StockFearGreedWidget> createState() => _StockFearGreedWidgetState();
}

class _StockFearGreedWidgetState extends State<StockFearGreedWidget> {
  int? _score;
  String? _rating;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _fetchIndex();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final score = prefs.getInt('stock_fg_score');
      final rating = prefs.getString('stock_fg_rating');
      final cacheTime = prefs.getInt('stock_fg_cache_time');
      if (score != null && rating != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            15 * 60 * 1000) {
          if (mounted) {
            setState(() {
              _score = score;
              _rating = rating;
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _cache(int score, String rating) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stock_fg_score', score);
      await prefs.setString('stock_fg_rating', rating);
      await prefs.setInt(
          'stock_fg_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchIndex() async {
    try {
      final baseUrl = Uri.base.origin;
      final res = await http
          .get(Uri.parse('$baseUrl/api/fear-greed'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final score = (data['score'] as num).toInt();
          final rating = data['rating']?.toString() ?? '';
          if (!mounted) return;
          setState(() {
            _score = score;
            _rating = rating;
            _isLoading = false;
          });
          await _cache(score, rating);
          return;
        }
      }
      throw Exception('HTTP ${res.statusCode}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  String _translateRating(String rating) {
    switch (rating.toLowerCase()) {
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
        return rating;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GaugeCard(
      isLoading: _isLoading,
      error: _error,
      value: _score ?? 0,
      title:
          '주식시장 공포탐욕지수 · ${_rating != null ? _translateRating(_rating!) : ''}',
      subtitle: 'CNN Business 기준 · 0(극도의 공포) ~ 100(극도의 탐욕)',
    );
  }
}
