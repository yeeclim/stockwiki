import 'package:flutter/foundation.dart';

/// 웹 환경의 베이스 URL (로컬 개발: localhost:3000, 프로덕션: 현재 오리진)
String get webBaseUrl {
  if (!kIsWeb) return 'https://stockwiki.vercel.app';
  try {
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:3000';
    }
    return origin;
  } catch (_) {
    return 'https://stockwiki.vercel.app';
  }
}
