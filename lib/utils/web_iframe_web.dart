// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

void registerSrcdocIframe(
  String viewType, {
  required String srcdoc,
  String? sandbox,
  bool allowFullscreen = false,
  bool focusable = true,
}) {
  try {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      final frame = html.IFrameElement()
        ..srcdoc = srcdoc
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allowFullscreen = allowFullscreen;
      if (!focusable) frame.tabIndex = -1;
      if (sandbox != null) frame.setAttribute('sandbox', sandbox);
      return frame;
    });
  } catch (_) {
    // 같은 viewType 이 이미 등록된 경우 무시
  }
}

/// 다이얼로그가 떠 있는 동안 iframe 이 마우스 이벤트를 가로채지 않도록 토글한다.
void setIframesPointerEvents(bool enabled) {
  for (final el in html.document.querySelectorAll('iframe')) {
    (el as html.IFrameElement).style.pointerEvents = enabled ? '' : 'none';
  }
}

Widget iframeView(String viewType) => HtmlElementView(viewType: viewType);
