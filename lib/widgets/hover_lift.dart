import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 마우스 hover 또는 터치 press 시 살짝 확대되며 떠오르는(렌즈 효과) 래퍼.
/// 다크에서는 네온 글로우, 라이트에서는 옅은 그림자+테두리로 반응한다.
class HoverLift extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _active = false;

  void _set(bool value) {
    if (_active != value) setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final market = theme.extension<MarketColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    // 스케일(바운스)과 그림자/테두리(선형)를 서로 다른 AnimatedWidget으로 분리한다.
    // 하나의 AnimatedContainer에서 easeOutBack으로 boxShadow까지 같이 보간하면,
    // 바운스 커브의 오버슈트 구간에서 blurRadius가 순간적으로 음수가 되어
    // "Text shadow blur radius should be non-negative" 어서션이 터진다.
    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        child: AnimatedScale(
          scale: _active ? 1.045 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _active ? -2.0 : 0.0, 0.0, 1.0),
            decoration: BoxDecoration(
              color: _active ? market.surfaceHover : Colors.transparent,
              borderRadius: widget.borderRadius,
              border:
                  _active ? Border.all(color: market.accent, width: 1) : null,
              boxShadow: _active
                  ? [
                      BoxShadow(
                        color: isDark
                            ? market.accentDim
                            : Colors.black.withValues(alpha: 0.14),
                        blurRadius: isDark ? 18 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
