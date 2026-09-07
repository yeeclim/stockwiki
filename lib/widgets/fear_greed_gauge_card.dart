import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import 'gauge_card.dart';

/// 공포탐욕지수 영문 분류를 한국어로 변환.
String translateFearGreedLabel(String label) {
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

typedef FearGreedResult = ({int value, String label});

/// 0~100 공포탐욕 게이지 공용 위젯.
/// 암호화폐(alternative.me)·주식시장(CNN) 두 위젯이 각자 복붙하던
/// 캐시(SharedPreferences 3키)·라벨 변환·게이지 렌더 로직을 통합한다.
class FearGreedGaugeCard extends StatefulWidget {
  final String cacheKey;
  final Duration cacheTtl;
  final Future<FearGreedResult?> Function() fetch;
  final String Function(String koLabel) buildTitle;
  final String subtitle;

  const FearGreedGaugeCard({
    super.key,
    required this.cacheKey,
    required this.cacheTtl,
    required this.fetch,
    required this.buildTitle,
    required this.subtitle,
  });

  @override
  State<FearGreedGaugeCard> createState() => _FearGreedGaugeCardState();
}

class _FearGreedGaugeCardState extends State<FearGreedGaugeCard> {
  int? _value;
  String? _label; // 한국어
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await CacheService.get(widget.cacheKey);
    if (cached is Map && mounted) {
      final v = (cached['value'] as num?)?.toInt();
      if (v != null) {
        setState(() {
          _value = v;
          _label = cached['label'] as String?;
          _isLoading = false;
        });
      }
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final result = await widget.fetch();
      if (result == null) throw Exception('no data');
      final ko = translateFearGreedLabel(result.label);
      if (!mounted) return;
      setState(() {
        _value = result.value;
        _label = ko;
        _isLoading = false;
      });
      await CacheService.set(
        widget.cacheKey,
        {'value': result.value, 'label': ko},
        expiration: widget.cacheTtl,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_value == null) _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GaugeCard(
      isLoading: _isLoading,
      error: _error,
      value: _value ?? 0,
      title: widget.buildTitle(_label ?? ''),
      subtitle: widget.subtitle,
    );
  }
}
