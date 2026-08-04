import 'package:flutter/material.dart';
import '../services/exchange_rate_service.dart';
import '../utils/number_format_utils.dart';
import 'market_data_card.dart';

class UsdKrwWidget extends StatefulWidget {
  const UsdKrwWidget({super.key});

  @override
  State<UsdKrwWidget> createState() => _UsdKrwWidgetState();
}

class _UsdKrwWidgetState extends State<UsdKrwWidget> {
  double? _usdKrw;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsdKrw();
  }

  Future<void> _fetchUsdKrw() async {
    try {
      final rate = await ExchangeRateService.getUsdToKrw();
      if (!mounted) return;
      setState(() {
        _usdKrw = rate;
        _error = rate == null ? '데이터 없음' : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터 로드 실패';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MarketDataCard(
        accentColor: Colors.indigo,
        headerIcon:
            const Icon(Icons.currency_exchange, color: Colors.indigo, size: 16),
        title: 'USD/KRW',
        isLoading: _isLoading,
        error: _error,
        valueText: _usdKrw != null
            ? '₩${formatWithCommas(_usdKrw!, decimals: 2)}'
            : 'N/A',
        subText: '원',
      );
}
