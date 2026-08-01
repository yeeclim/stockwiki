import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:k_chart_plus/k_chart_plus.dart';

/// 국내주식 일봉 데이터 조회 (KIS Open API를 백엔드에서 프록시하는 /api/kr-chart)
class KrChartService {
  static Future<List<KLineEntity>> fetchDailyCandles(String code) async {
    final origin = kIsWeb ? Uri.base.origin : 'https://stockwiki.vercel.app';
    final url = '$origin/api/utils?type=kr-candles&code=$code';

    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('차트 데이터 조회 실패 (${res.statusCode})');
    }
    final body = json.decode(res.body);
    if (body['success'] != true) {
      throw Exception(body['error'] ?? '차트 데이터 조회 실패');
    }

    final List<dynamic> rows = body['data'] ?? [];
    return rows
        .map((row) => KLineEntity.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
