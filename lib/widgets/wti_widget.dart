import 'package:flutter/material.dart';
import 'yahoo_price_widget.dart';

class WtiWidget extends StatelessWidget {
  const WtiWidget({super.key});

  @override
  Widget build(BuildContext context) => const YahooPriceWidget(
        cacheKey: 'wti',
        symbols: ['CL=F'],
        cacheTtl: Duration(minutes: 10),
        accentColor: Colors.teal,
        headerIcon: Icon(Icons.opacity, color: Colors.teal, size: 16),
        title: 'WTI 유가',
        // 야후 무료 선물 시세(COMEX/NYMEX)는 약 10분 늦다 (2026-09-17 실측)
        delayNote: '10분 지연',
      );
}
