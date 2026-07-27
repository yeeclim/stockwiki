import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gauge_card.dart';

/// 주식시장 심리 — VIX(변동성지수) 기반 약식 공포탐욕 게이지.
///
/// CNN의 공식 Fear & Greed Index는 7개 지표(모멘텀·주가강도·주가폭·풋콜비율·
/// VIX·안전자산 수요·정크본드 수요)를 종합하는데, 그 원본 데이터를 무료로 받을
/// 방법이 없어 그중 시장 변동성(VIX) 하나만으로 0~100 스케일에 매핑한
/// 간이 지표다. CNN 수치와 다를 수 있다.
class StockFearGreedWidget extends StatefulWidget {
  const StockFearGreedWidget({super.key});

  @override
  State<StockFearGreedWidget> createState() => _StockFearGreedWidgetState();
}

class _StockFearGreedWidgetState extends State<StockFearGreedWidget> {
  double? _vix;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedVix();
    _fetchVix();
  }

  Future<void> _loadCachedVix() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getDouble('vix_value');
      final cacheTime = prefs.getInt('vix_cache_time');
      if (cached != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            15 * 60 * 1000) {
          if (mounted)
            setState(() {
              _vix = cached;
              _isLoading = false;
            });
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheVix(double vix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('vix_value', vix);
      await prefs.setInt(
          'vix_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchVix() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'market-data',
        body: {'symbol': '^VIX'},
      );
      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final meta = data['chart']?['result']?[0]?['meta'];
        final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
        if (price != null && (price as num) > 0) {
          if (!mounted) return;
          setState(() {
            _vix = price.toDouble();
            _isLoading = false;
          });
          await _cacheVix(_vix!);
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

  /// VIX를 0~100 공포탐욕 스케일로 변환 (낮은 VIX=탐욕, 높은 VIX=공포).
  /// 기준: VIX 12 이하 극도의 탐욕(100), VIX 35 이상 극도의 공포(0), 그 사이 선형 보간.
  int _vixToScore(double vix) {
    const lowAnchor = 12.0; // 매우 낮은 변동성 → 시장 안일(탐욕)
    const highAnchor = 35.0; // 매우 높은 변동성 → 시장 공포
    final t = ((vix - lowAnchor) / (highAnchor - lowAnchor)).clamp(0.0, 1.0);
    return (100 - t * 100).round();
  }

  String _scoreLabel(int score) {
    if (score <= 24) return '극도의 공포';
    if (score <= 44) return '공포';
    if (score <= 55) return '중립';
    if (score <= 75) return '탐욕';
    return '극도의 탐욕';
  }

  @override
  Widget build(BuildContext context) {
    final score = _vix != null ? _vixToScore(_vix!) : 0;
    return GaugeCard(
      isLoading: _isLoading,
      error: _error,
      value: score,
      title: '주식시장 공포탐욕지수 · ${_vix != null ? _scoreLabel(score) : ''}',
      subtitle: _vix != null
          ? 'VIX ${_vix!.toStringAsFixed(1)} 기준 약식 산출 (CNN 지수와 다를 수 있음)'
          : '0(극도의 공포) ~ 100(극도의 탐욕)',
    );
  }
}
