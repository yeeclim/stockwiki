import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:k_chart_plus/k_chart_plus.dart';

/// 차트 시장 구분.
enum ChartMarket {
  /// 국내 — KIS Open API (서버에서 프록시)
  kr,

  /// 미국 — Yahoo Finance (서버에서 프록시)
  us,
}

/// 일/주/월봉 데이터 조회.
///
/// 국내(`kr-candles`)와 미국(`us-candles`) 모두 `/api/utils` 가 같은 JSON 형태
/// (`{time, open, high, low, close, vol}`)로 내려주므로 파싱 경로는 하나다.
///
/// 미국은 예전에 finviz 차트 PNG 를 이미지로 받아 보여줬는데, finviz 가
/// Cloudflare 로 막히면서 차트가 통째로 죽었다. 이미지 소스 한 곳에 매달리는 대신
/// 국내와 같은 데이터 기반 차트로 합쳤다.
class ChartService {
  /// [period]: 'D'(일봉) | 'W'(주봉) | 'M'(월봉)
  static Future<List<KLineEntity>> fetchCandles(
    String code, {
    ChartMarket market = ChartMarket.kr,
    String period = 'D',
  }) async {
    final origin = kIsWeb ? Uri.base.origin : 'https://stockwiki.vercel.app';
    // 국내는 종목코드(code), 미국은 심볼(symbol) 파라미터를 쓴다.
    final url = market == ChartMarket.kr
        ? '$origin/api/utils?type=kr-candles&code=$code&period=$period'
        : '$origin/api/utils?type=us-candles&symbol=${Uri.encodeQueryComponent(code)}&period=$period';

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
