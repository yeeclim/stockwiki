import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SilverWidget extends StatefulWidget {
  const SilverWidget({super.key});

  @override
  State<SilverWidget> createState() => _SilverWidgetState();
}

class _SilverWidgetState extends State<SilverWidget> {
  double? _silverPrice;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedPrice();
    _fetchSilverPrice();
  }

  // 캐시된 가격 로드
  Future<void> _loadCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getDouble('silver_price');
      final cacheTime = prefs.getInt('silver_cache_time');
      
      if (cachedPrice != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 10분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 10 * 60 * 1000) {
          setState(() {
            _silverPrice = cachedPrice;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 캐시 로드 실패 시 무시
    }
  }

  // 가격 캐시 저장
  Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('silver_price', price);
      await prefs.setInt('silver_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
  }

  Future<void> _fetchSilverPrice() async {
    // 최적화: 주요 API만 사용 (3개로 줄임)
    try {
      final results = await Future.wait([
        _tryYahooFinance(),
      ], eagerError: false).timeout(const Duration(seconds: 5));

      // 첫 번째 유효한 가격 찾기
      for (final price in results) {
        if (price != null && price > 0) {
          setState(() {
            _silverPrice = price;
            _isLoading = false;
          });
          await _cachePrice(price);
          return;
        }
      }
    } catch (e) {
      // 병렬 호출 실패 시
      setState(() {
        _error = '데이터 로드 실패';
        _isLoading = false;
      });
      return;
    }

    // 모든 시도 실패 시
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  // Yahoo Finance (무료, API 키 불필요)
  Future<double?> _tryYahooFinance() async {
    try {
      // 병렬로 여러 Yahoo Finance 엔드포인트 시도
      final urls = [
        '/api/commodity-price?symbol=SI=F',
        '/api/commodity-price?symbol=XAGUSD=X',
      ];
      
      final futures = urls.map((url) async {
        try {
          final response = await http.get(
            Uri.parse(url),
          ).timeout(const Duration(seconds: 3));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final result = data['chart']?['result']?[0];
            if (result != null) {
              final meta = result['meta'];
              if (meta != null) {
                final price = meta?['regularMarketPrice'] ?? 
                             meta?['previousClose'] ?? 
                             meta?['chartPreviousClose'];
                if (price != null) {
                  return price.toDouble();
                }
              }
            }
          }
        } catch (e) {
          return null;
        }
        return null;
      });

      final results = await Future.wait(futures);
      for (final price in results) {
        if (price != null && price > 0) {
          return price;
        }
      }
    } catch (e) {
      // Yahoo Finance error
    }
    return null;
  }

  // 외부 API 호출 제거 (CORS 문제로 프록시만 사용)
  Future<double?> _tryTwelveData() async => null;
  Future<double?> _tryGoldAPI() async => null;
  Future<double?> _trySimpleAPI() async => null;
  Future<double?> _tryFixerIO() async => null;



  @override
  Widget build(BuildContext context) {
    const double krwPerUsd = 1383.66; // 환율
    const double ozToDon = 1 / 7.5599; // 1 oz ≒ 7.5599 돈

    double? krwPerDon;
    if (_silverPrice != null) {
      krwPerDon = _silverPrice! * krwPerUsd * ozToDon;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = Colors.blueGrey;

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [accentColor.withOpacity(0.15), Colors.transparent]
                : [accentColor.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.trending_neutral, // Or another icon
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Silver',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (_isLoading)
               Center(
                  child: SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)
                  )
               )
            else if (_error != null)
              Center(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                )
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${_silverPrice!.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor, 
                    ),
                  ),
                  if (krwPerDon != null)
                    Text(
                      '약 ${krwPerDon.toStringAsFixed(0)}원 / 돈',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
