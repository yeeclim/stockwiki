import 'package:flutter/material.dart';

/// 웹이 아닌 플랫폼: iframe 을 만들 수 없으므로 등록은 무시한다.
void registerSrcdocIframe(
  String viewType, {
  required String srcdoc,
  String? sandbox,
  bool allowFullscreen = false,
  bool focusable = true,
}) {}

/// 웹이 아닌 플랫폼에는 iframe 이 없다.
void setIframesPointerEvents(bool enabled) {}

Widget iframeView(String viewType) => const Center(
      child: Text('이 콘텐츠는 웹에서만 표시됩니다.'),
    );
