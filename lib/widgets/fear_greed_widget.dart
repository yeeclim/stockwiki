import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'fear_greed_gauge_card.dart';

/// 암호화폐(비트코인) 시장 심리 — alternative.me Crypto Fear & Greed Index.
/// 주의: CNN의 주식시장용 Fear & Greed Index와는 다른 별개의 지표다.
/// 주식시장 심리는 [StockFearGreedWidget](VIX 기준)을 참고할 것.
class FearGreedWidget extends StatelessWidget {
  const FearGreedWidget({super.key});

  Future<FearGreedResult?> _fetch() async {
    // api.alternative.me — 암호화폐(비트코인) 전용 공포탐욕지수, 무료 공개 API
    final res = await http
        .get(Uri.parse('https://api.alternative.me/fng/?limit=1'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final item = jsonDecode(res.body)['data']?[0];
    final value = int.tryParse(item?['value']?.toString() ?? '');
    if (value == null) return null;
    return (
      value: value,
      label: item?['value_classification']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) => FearGreedGaugeCard(
        cacheKey: 'fear_greed_crypto',
        cacheTtl: const Duration(minutes: 30),
        fetch: _fetch,
        buildTitle: (label) => '암호화폐 공포탐욕지수 · $label',
        subtitle: '비트코인 시장 심리 · 0(극도의 공포) ~ 100(극도의 탐욕)',
      );
}
