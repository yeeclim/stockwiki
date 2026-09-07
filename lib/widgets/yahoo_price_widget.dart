import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/number_format_utils.dart';
import 'market_data_card.dart';

/// Yahoo Finance(`market-data` Supabase 함수) 시세를 한 줄로 보여주는 공용 위젯.
/// Gold·Silver·WTI 위젯이 각자 복붙하던 fetch/파싱/캐시/렌더 로직을 통합한다.
/// (BTC·USD/KRW 는 데이터 소스가 달라 별도 위젯 유지)
class YahooPriceWidget extends StatefulWidget {
  final String cacheKey;
  final List<String> symbols;
  final Duration cacheTtl;
  final Color accentColor;
  final Widget headerIcon;
  final String title;
  final int decimals;

  /// true면 온스→돈 환산가를 부제로 표시(귀금속). USD/KRW 환율을 추가 조회한다.
  final bool perDonSubtext;

  const YahooPriceWidget({
    super.key,
    required this.cacheKey,
    required this.symbols,
    required this.cacheTtl,
    required this.accentColor,
    required this.headerIcon,
    required this.title,
    this.decimals = 2,
    this.perDonSubtext = false,
  });

  @override
  State<YahooPriceWidget> createState() => _YahooPriceWidgetState();
}

class _YahooPriceWidgetState extends State<YahooPriceWidget> {
  double? _price;
  double? _changePercent;
  double? _usdKrwRate;
  bool _isLoading = true;
  String? _error;

  String get _priceCacheKey => '${widget.cacheKey}_price';

  @override
  void initState() {
    super.initState();
    _loadCached();
    _fetchPrice();
    if (widget.perDonSubtext) _fetchExchangeRate();
  }

  Future<void> _fetchExchangeRate() async {
    final rate = await ExchangeRateService.getUsdToKrw();
    if (mounted) setState(() => _usdKrwRate = rate);
  }

  Future<void> _loadCached() async {
    final cached = await CacheService.get(_priceCacheKey);
    if (cached is num && mounted) {
      setState(() {
        _price = cached.toDouble();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPrice() async {
    for (final symbol in widget.symbols) {
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'market-data',
          body: {'symbol': symbol},
        );
        if (res.status == 200 && res.data != null) {
          final data = res.data as Map<String, dynamic>;
          final meta = data['chart']?['result']?[0]?['meta'];
          final price = meta?['regularMarketPrice'] ?? meta?['previousClose'];
          final prevClose = meta?['previousClose'];
          if (price != null && (price as num) > 0) {
            if (!mounted) return;
            final priceValue = price.toDouble();
            setState(() {
              _price = priceValue;
              if (prevClose != null && (prevClose as num) > 0) {
                _changePercent = (priceValue - prevClose.toDouble()) /
                    prevClose.toDouble() *
                    100;
              }
              _isLoading = false;
            });
            await CacheService.set(_priceCacheKey, priceValue,
                expiration: widget.cacheTtl);
            return;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      if (_price == null) _error = '데이터 없음';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String? subText;
    if (widget.perDonSubtext &&
        _price != null &&
        _usdKrwRate != null &&
        _usdKrwRate! > 0) {
      const ozToDon = 1 / 7.5599;
      final krwPerDon = _price! * _usdKrwRate! * ozToDon;
      subText = '약 ${formatWithCommas(krwPerDon)}원 / 돈';
    }

    return MarketDataCard(
      accentColor: widget.accentColor,
      headerIcon: widget.headerIcon,
      title: widget.title,
      isLoading: _isLoading,
      error: _error,
      valueText: _price != null
          ? '\$${formatWithCommas(_price!, decimals: widget.decimals)}'
          : 'N/A',
      subText: subText,
      changePercent: _changePercent,
    );
  }
}
