import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// FMP / Finnhub API 요청을 Supabase Edge Function(fmp-proxy)을 통해 전달합니다.
/// API 키는 서버(Edge Function)에만 보관되며 클라이언트에 노출되지 않습니다.
///
/// [service] : 'fmp' 또는 'finnhub'
/// [path]    : API 경로 (예: '/search', '/quote/AAPL')
/// [params]  : 쿼리 파라미터 (API 키 제외 — 서버에서 자동 추가)
Future<dynamic> callProxy(
  String service,
  String path, {
  Map<String, String> params = const {},
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    final res = await Supabase.instance.client.functions.invoke('fmp-proxy',
        body: {
          'service': service,
          'path': path,
          'params': params
        }).timeout(timeout);
    if (res.status == 200) return res.data;
    debugPrint('[fmp-proxy] $service$path → HTTP ${res.status}');
    return null;
  } catch (e) {
    debugPrint('[fmp-proxy] error $service$path: $e');
    return null;
  }
}

/// 지수 백오프 재시도 HTTP GET
/// [maxAttempts] 기본 3회, [baseDelay] 첫 재시도 대기 시간
Future<http.Response> getWithRetry(
  Uri uri, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 10),
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final response = await http.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode < 500) return response;
      // 5xx 서버 오류는 재시도 대상
    } catch (e) {
      debugPrint('[http] GET attempt $attempt/$maxAttempts failed: $e');
    }

    if (attempt < maxAttempts) {
      await Future.delayed(baseDelay * (1 << (attempt - 1)));
    }
  }
  // 마지막 시도는 예외를 그냥 throw
  return http.get(uri, headers: headers).timeout(timeout);
}

/// 지수 백오프 재시도 HTTP POST
Future<http.Response> postWithRetry(
  Uri uri, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  Map<String, String>? headers,
  Object? body,
  Duration timeout = const Duration(seconds: 10),
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final response =
          await http.post(uri, headers: headers, body: body).timeout(timeout);
      if (response.statusCode < 500) return response;
    } catch (e) {
      debugPrint('[http] POST attempt $attempt/$maxAttempts failed: $e');
    }

    if (attempt < maxAttempts) {
      await Future.delayed(baseDelay * (1 << (attempt - 1)));
    }
  }
  return http.post(uri, headers: headers, body: body).timeout(timeout);
}
