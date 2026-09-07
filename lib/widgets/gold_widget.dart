import 'package:flutter/material.dart';
import 'yahoo_price_widget.dart';

class GoldWidget extends StatelessWidget {
  const GoldWidget({super.key});

  @override
  Widget build(BuildContext context) => const YahooPriceWidget(
        cacheKey: 'gold',
        symbols: ['GC=F', 'XAUUSD=X'],
        cacheTtl: Duration(minutes: 5),
        accentColor: Colors.amber,
        headerIcon: Text('Au',
            style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        title: 'Gold',
        perDonSubtext: true,
      );
}
