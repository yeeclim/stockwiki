import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'hover_lift.dart';

/// 0~100 원형 게이지 카드 — 공포탐욕지수류 위젯 공용(암호화폐/주식시장).
/// 진입 시 0→value로 채워지는 애니메이션과 hover/press 확대 반응을 포함한다.
class GaugeCard extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final int value; // 0~100
  final String title;
  final String subtitle;

  const GaugeCard({
    super.key,
    required this.isLoading,
    required this.value,
    required this.title,
    required this.subtitle,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final market = theme.extension<MarketColors>()!;

    Widget content;
    if (isLoading) {
      content =
          Text('불러오는 중…', style: TextStyle(color: market.muted, fontSize: 12));
    } else if (error != null) {
      content =
          Text(error!, style: TextStyle(color: market.muted, fontSize: 12));
    } else {
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
                Text(title,
                    style: TextStyle(
                        color: market.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(subtitle,
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
