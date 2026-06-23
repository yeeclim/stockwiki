// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class TradingViewChart extends StatefulWidget {
  final String tvSymbol; // e.g. "KRX:005930" or "NASDAQ:AAPL"
  final bool isDark;

  const TradingViewChart({
    super.key,
    required this.tvSymbol,
    this.isDark = true,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    final safeId = widget.tvSymbol.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final themeId = widget.isDark ? 'dark' : 'light';
    _viewType = 'tv_${safeId}_$themeId';
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        final theme = widget.isDark ? 'dark' : 'light';
        // XSS 방지: 심볼에서 따옴표 제거
        final symbol = widget.tvSymbol.replaceAll('"', '').replaceAll("'", '');
        final srcdoc = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:100%;height:100%;overflow:hidden;background:#000}
</style>
</head>
<body>
<div id="tv" style="width:100%;height:100%"></div>
<script src="https://s3.tradingview.com/tv.js"></script>
<script>
new TradingView.widget({
  autosize:true,
  symbol:"$symbol",
  interval:"D",
  timezone:"Asia/Seoul",
  theme:"$theme",
  style:"1",
  locale:"kr",
  enable_publishing:false,
  allow_symbol_change:false,
  container_id:"tv"
});
</script>
</body>
</html>''';
        return html.IFrameElement()
          ..srcdoc = srcdoc
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..allowFullscreen = true;
      });
    } catch (_) {
      // 동일 viewType이 이미 등록된 경우 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
