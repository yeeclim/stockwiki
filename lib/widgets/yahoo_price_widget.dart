import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/number_format_utils.dart';
import 'market_data_card.dart';
import 'periodic_refresh.dart';

/// Yahoo Finance(`market-data` Supabase 함수) 시세를 한 줄로 보여주는 공용 위젯.
/// Gold·Silver·WTI·USD/KRW 위젯이 공유한다. (BTC 는 데이터 소스가 달라 별도 위젯 유지)
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

  /// 가격 앞 통화 기호 (기본 달러)
  final String valuePrefix;

  /// 고정 부제 (perDonSubtext 가 아닐 때)
  final String? subText;

  /// Yahoo 조회가 모두 실패했을 때 가격만이라도 가져올 대체 경로 (등락률은 표시 안 함)
  final Future<double?> Function()? fallbackPrice;

  /// 데이터 지연 안내 (예: 야후 무료 선물 시세 '10분 지연')
  final String? delayNote;

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
    this.valuePrefix = '\$',
    this.subText,
    this.fallbackPrice,
    this.delayNote,
  });

  @override
  State<YahooPriceWidget> createState() => _YahooPriceWidgetState();
}

class _YahooPriceWidgetState extends State<YahooPriceWidget>
    with PeriodicRefresh {
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
    startPeriodicRefresh();
  }

  @override
  Future<void> onPeriodicRefresh() => _fetchPrice();

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
          // range=1d 응답에서는 previousClose 가 비어 있고 전일 종가가 chartPreviousClose 에
          // 들어온다. previousClose 만 보던 탓에 금·은·WTI 등락률이 표시되지 않았다.
          final prevClose =
              meta?['previousClose'] ?? meta?['chartPreviousClose'];
          final price = meta?['regularMarketPrice'] ?? prevClose;
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
    // 대체 경로는 아직 가격이 하나도 없을 때만 쓴다. 자동 갱신 중 일시적 실패로
    // 이미 보이던 등락률이 지워지지 않게 하기 위해서다.
    final fallback = widget.fallbackPrice;
    if (fallback != null && _price == null) {
      final price = await fallback();
      if (price != null && price > 0 && mounted) {
        setState(() {
          _price = price;
          _changePercent = null;
          _error = null;
          _isLoading = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      if (_price == null) _error = '데이터 없음';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String? subText = widget.subText;
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
          ? '${widget.valuePrefix}${formatWithCommas(_price!, decimals: widget.decimals)}'
          : 'N/A',
      subText: subText,
      changePercent: _changePercent,
      delayNote: widget.delayNote,
    );
  }
}
