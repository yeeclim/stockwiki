import 'package:flutter/material.dart';
import '../services/exchange_rate_service.dart';
import 'yahoo_price_widget.dart';

/// USD/KRW 환율. 등락률을 보여주기 위해 Yahoo(KRW=X) 시세를 쓰고,
/// Yahoo 가 실패하면 기존 환율 API(open.er-api.com)로 가격만 표시한다.
class UsdKrwWidget extends StatelessWidget {
  const UsdKrwWidget({super.key});

  @override
  Widget build(BuildContext context) => const YahooPriceWidget(
        cacheKey: 'usdkrw',
        symbols: ['KRW=X'],
        cacheTtl: Duration(minutes: 10),
        accentColor: Colors.indigo,
        headerIcon:
            Icon(Icons.currency_exchange, color: Colors.indigo, size: 16),
        title: 'USD/KRW',
        valuePrefix: '₩',
        subText: '원',
        fallbackPrice: ExchangeRateService.getUsdToKrw,
      );
}
