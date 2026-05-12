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
    _viewType = 'tv_$safeId';
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        final theme = widget.isDark ? 'dark' : 'light';
        final encoded = Uri.encodeComponent(widget.tvSymbol);
        return html.IFrameElement()
          ..src = 'https://www.tradingview.com/widgetembed/'
              '?symbol=$encoded'
              '&interval=D'
              '&theme=$theme'
              '&locale=kr'
              '&style=1'
              '&hide_top_toolbar=0'
              '&save_image=0'
              '&allow_symbol_change=0'
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
