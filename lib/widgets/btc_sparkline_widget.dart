import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

/// BTC 24시간 가격 추이를 보여주는 미니 차트.
/// 데이터가 로드되면 왼쪽에서 오른쪽으로 선이 그려지는 애니메이션을 재생한다.
class BtcSparklineWidget extends StatefulWidget {
  const BtcSparklineWidget({super.key});

  @override
  State<BtcSparklineWidget> createState() => _BtcSparklineWidgetState();
}

class _BtcSparklineWidgetState extends State<BtcSparklineWidget> {
  List<double>? _prices;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _fetchHistory();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('btc_sparkline');
      final cacheTime = prefs.getInt('btc_sparkline_cache_time');
      if (cached != null && cacheTime != null) {
        if (DateTime.now().millisecondsSinceEpoch - cacheTime <
            10 * 60 * 1000) {
          final list = (jsonDecode(cached) as List)
              .map((e) => (e as num).toDouble())
              .toList();
          if (mounted) {
            setState(() {
              _prices = list;
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _cache(List<double> prices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('btc_sparkline', jsonEncode(prices));
      await prefs.setInt(
          'btc_sparkline_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http
          .get(Uri.parse(
              'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawPrices = (data['prices'] as List?) ?? [];
        final prices = rawPrices.map((p) => (p[1] as num).toDouble()).toList();
        if (prices.length >= 2) {
          if (!mounted) return;
          setState(() {
            _prices = prices;
            _isLoading = false;
          });
          await _cache(prices);
          return;
        }
      }
      throw Exception('no data');
    } catch (_) {
      if (!mounted) return;
      if (_prices == null) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = Theme.of(context).extension<MarketColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (_isLoading) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text('차트 로딩중…',
              style: TextStyle(color: market.muted, fontSize: 11)),
        ),
      );
    }
    if (_prices == null || _prices!.length < 2) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text('차트 데이터 없음',
              style: TextStyle(color: market.muted, fontSize: 11)),
        ),
      );
    }

    final spots = <FlSpot>[
      for (int i = 0; i < _prices!.length; i++)
        FlSpot(i.toDouble(), _prices![i]),
    ];
    final minY = _prices!.reduce((a, b) => a < b ? a : b);
    final maxY = _prices!.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.1;

    final chart = LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: market.accent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  market.accent.withValues(alpha: 0.32),
                  market.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );

    return SizedBox(
      height: 40,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_prices!.length),
        tween: Tween(begin: 0.0, end: 1.0),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, t, (t + 0.001).clamp(0.0, 1.0)],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: isDark
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: market.accentDim,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: chart,
                  )
                : chart,
          );
        },
      ),
    );
  }
}
