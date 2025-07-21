// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;

/// Flutter Web에서 iframe을 등록하는 함수입니다.
void registerVixIframeViewFactory() {
  // 👇 이 한 줄이 에러 안 나게 만드는 핵심!
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'vix-iframe',
    (int viewId) => html.IFrameElement()
      ..src = 'https://s.tradingview.com/embed-widget/mini-symbol-overview/?locale=kr&symbol=CBOE%3AVIX&width=100%25&height=220&colorTheme=dark'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true,
  );
}
