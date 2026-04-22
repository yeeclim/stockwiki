import 'package:http/http.dart' as http;

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
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode < 500) return response;
      // 5xx 서버 오류는 재시도 대상
    } catch (_) {
      // 네트워크 오류도 재시도
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
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
      if (response.statusCode < 500) return response;
    } catch (_) {}

    if (attempt < maxAttempts) {
      await Future.delayed(baseDelay * (1 << (attempt - 1)));
    }
  }
  return http.post(uri, headers: headers, body: body).timeout(timeout);
}
