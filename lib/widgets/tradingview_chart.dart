import 'dart:convert';

import 'package:flutter/material.dart';

import '../utils/web_iframe.dart';

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
    final theme = widget.isDark ? 'dark' : 'light';
    // XSS 방지: 따옴표만 지우면 </script> 같은 입력을 못 막는다.
    // JSON 문자열 리터럴로 넣고 '</' 를 이스케이프해 스크립트 블록을 벗어날 수 없게 한다.
    final symbol = jsonEncode(widget.tvSymbol).replaceAll('</', r'<\/');
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
  symbol:$symbol,
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
    registerSrcdocIframe(_viewType, srcdoc: srcdoc, allowFullscreen: true);
  }

  @override
  Widget build(BuildContext context) => iframeView(_viewType);
}
