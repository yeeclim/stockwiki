import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'fear_greed_gauge_card.dart';

/// 주식시장 심리 — CNN Business의 실제 Fear & Greed Index.
/// api/utils.js(type=cnn-fear-greed)가 CNN의 비공식 데이터 엔드포인트를 그대로 프록시하므로
/// CNN 웹페이지에 나오는 수치와 동일하다(약식 근사치가 아님).
class StockFearGreedWidget extends StatelessWidget {
  const StockFearGreedWidget({super.key});

  Future<FearGreedResult?> _fetch() async {
    final res = await http
        .get(Uri.parse('${Uri.base.origin}/api/utils?type=cnn-fear-greed'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data['success'] != true || data['score'] == null) return null;
    return (
      value: (data['score'] as num).toInt(),
      label: data['rating']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) => FearGreedGaugeCard(
        cacheKey: 'fear_greed_stock',
        cacheTtl: const Duration(minutes: 15),
        fetch: _fetch,
        buildTitle: (label) => '주식시장 공포탐욕지수 · $label',
        subtitle: 'CNN Business 기준 · 0(극도의 공포) ~ 100(극도의 탐욕)',
      );
}
