import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'hover_lift.dart';

/// 증권 터미널 스타일의 시세 목록 컨테이너.
/// children 사이에 구분선을 넣고 각 child는 HoverLift로 감싸 hover/press 시
/// 확대·글로우 반응을 준다. overflow는 일부러 clip하지 않아(내부 Container에
/// ClipRRect를 쓰지 않음) hover 시 살짝 확대된 행이 테두리 밖으로 자연스럽게
/// 튀어나올 수 있게 둔다.
class TerminalGrid extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry rowPadding;

  const TerminalGrid({
    super.key,
    required this.children,
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final market = Theme.of(context).extension<MarketColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: market.surface,
        border: Border.all(color: market.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: market.line),
            HoverLift(
              borderRadius: BorderRadius.circular(6),
              child: Padding(padding: rowPadding, child: children[i]),
            ),
          ],
        ],
      ),
    );
  }
}
