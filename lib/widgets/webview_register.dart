// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerVixIframeViewFactory() {
  ui_web.platformViewRegistry.registerViewFactory(
    'vix-iframe',
    (int viewId) => html.IFrameElement()
      ..src =
          'https://s.tradingview.com/embed-widget/mini-symbol-overview/?locale=kr&symbol=CBOE%3AVIX&width=100%25&height=220&colorTheme=dark'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true,
  );
}
