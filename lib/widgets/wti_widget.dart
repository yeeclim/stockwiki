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
      );
}
