import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import '../services/kr_chart_service.dart';
import 'kr_volume_profile_widget.dart';

/// 국내주식 실차트 — KIS Open API 일봉 데이터 + k_chart_plus 지표 렌더링.
class KrStockKChartWidget extends StatefulWidget {
  final String symbol;

  const KrStockKChartWidget({super.key, required this.symbol});

  @override
  State<KrStockKChartWidget> createState() => _KrStockKChartWidgetState();
}

class _KrStockKChartWidgetState extends State<KrStockKChartWidget> {
  List<KLineEntity>? _candles;
  bool _isLoading = true;
  String? _error;

  // 메인 차트 위 오버레이 지표
  final MAIndicator _maIndicator =
      MAIndicator(calcParams: const [10, 20, 60, 120, 200, 400]);
  final BOLLIndicator _bollIndicator = BOLLIndicator();

  // 보조 차트(하단 서브패널) 지표
  final MACDIndicator _macdIndicator = MACDIndicator();
  final RSIIndicator _rsiIndicator = RSIIndicator();
  final KDJIndicator _kdjIndicator = KDJIndicator();

  final List<MainIndicator> _activeMain = [];
  final List<SecondaryIndicator> _activeSecondary = [];

  @override
  void initState() {
    super.initState();
    _activeMain.add(_maIndicator);
    _activeSecondary.add(_rsiIndicator);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final candles = await KrChartService.fetchDailyCandles(widget.symbol);
      if (candles.isEmpty) {
        throw Exception('차트 데이터가 없습니다');
      }
      DataUtil.calculateAll(
        candles,
        [_maIndicator, _bollIndicator],
        [_macdIndicator, _rsiIndicator, _kdjIndicator],
      );
      if (!mounted) return;
      setState(() {
        _candles = candles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '차트를 불러오지 못했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleMain(MainIndicator indicator) {
    setState(() {
      if (_activeMain.contains(indicator)) {
        _activeMain.remove(indicator);
      } else {
        _activeMain.add(indicator);
      }
    });
  }

  void _toggleSecondary(SecondaryIndicator indicator) {
    setState(() {
      if (_activeSecondary.contains(indicator)) {
        _activeSecondary.remove(indicator);
      } else {
        _activeSecondary.add(indicator);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _candles == null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? '차트 데이터 없음',
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 360 +
              (_activeSecondary.isEmpty ? 0 : 90.0 * _activeSecondary.length),
          child: KChartWidget(
            _candles,
            const KChartStyle(),
            const KChartColors(),
            isTrendLine: false,
            mainIndicators: _activeMain,
            secondaryIndicators: _activeSecondary,
            mBaseHeight: 300,
            mSecondaryHeight: 90,
            fixedLength: 2,
            timeFormat: TimeFormat.YEAR_MONTH_DAY,
            detailBuilder: (entity) => _DetailPopup(entity: entity),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chip(context, 'MA', _activeMain.contains(_maIndicator),
                  () => _toggleMain(_maIndicator)),
              _chip(context, 'BOLL', _activeMain.contains(_bollIndicator),
                  () => _toggleMain(_bollIndicator)),
              _chip(context, 'RSI', _activeSecondary.contains(_rsiIndicator),
                  () => _toggleSecondary(_rsiIndicator)),
              _chip(context, 'MACD', _activeSecondary.contains(_macdIndicator),
                  () => _toggleSecondary(_macdIndicator)),
              _chip(
                  context,
                  'KDJ(스토캐스틱)',
                  _activeSecondary.contains(_kdjIndicator),
                  () => _toggleSecondary(_kdjIndicator)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KrVolumeProfileWidget(candles: _candles!),
      ],
    );
  }

  Widget _chip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color:
            selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _DetailPopup extends StatelessWidget {
  final KLineEntity entity;
  const _DetailPopup({required this.entity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('시가 ${entity.open.toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall),
          Text('고가 ${entity.high.toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall),
          Text('저가 ${entity.low.toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall),
          Text('종가 ${entity.close.toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall),
          Text('거래량 ${entity.vol.toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
