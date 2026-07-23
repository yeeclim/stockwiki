import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'hover_lift.dart';

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
      // api.alternative.me — 무료 공개 API, CORS 지원
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
    final theme = Theme.of(context);
    final market = theme.extension<MarketColors>()!;

    Widget content;
    if (_isLoading) {
      content =
          Text('불러오는 중…', style: TextStyle(color: market.muted, fontSize: 12));
    } else if (_error != null) {
      content =
          Text(_error!, style: TextStyle(color: market.muted, fontSize: 12));
    } else {
      final value = _indexValue ?? 0;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      content = Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(value),
              tween: Tween(begin: 0.0, end: value.toDouble()),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(64, 64),
                      painter: _GaugePainter(
                        value: animatedValue,
                        track: market.track,
                        accent: market.accent,
                        glow: theme.brightness == Brightness.dark,
                      ),
                    ),
                    Text(
                      animatedValue.round().toString(),
                      style: TextStyle(
                        color: market.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('공포탐욕지수 · ${_label ?? ''}',
                    style: TextStyle(
                        color: market.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('0(극도의 공포) ~ 100(극도의 탐욕)',
                    style: TextStyle(color: market.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      );
    }

    return HoverLift(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: market.surface,
          border: Border.all(color: market.line),
          borderRadius: BorderRadius.circular(3),
        ),
        child: content,
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value; // 0~100
  final Color track;
  final Color accent;
  final bool glow;

  _GaugePainter({
    required this.value,
    required this.track,
    required this.accent,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 8) / 2;
    const strokeWidth = 8.0;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = (value.clamp(0, 100) / 100) * 2 * math.pi;
    final fillPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (glow) {
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2, sweep, false, glowPaint);
    }

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}
