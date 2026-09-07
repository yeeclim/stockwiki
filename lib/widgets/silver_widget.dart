import 'package:flutter/material.dart';
import 'yahoo_price_widget.dart';

class SilverWidget extends StatelessWidget {
  const SilverWidget({super.key});

  @override
  Widget build(BuildContext context) => const YahooPriceWidget(
        cacheKey: 'silver',
        symbols: ['SI=F', 'XAGUSD=X'],
        cacheTtl: Duration(minutes: 10),
        accentColor: Colors.blueGrey,
        headerIcon: Text('Ag',
            style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        title: 'Silver',
        perDonSubtext: true,
      );
}
