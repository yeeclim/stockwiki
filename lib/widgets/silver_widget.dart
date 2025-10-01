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
        // 5분 이내 캐시된 데이터가 있으면 사용
        if (now - cacheTime < 5 * 60 * 1000) {
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
    // 여러 API를 순차적으로 시도
    final apis = [
      _tryFixerIO,
      _trySimpleAPI,
      _tryYahooFinance,
      _tryTwelveData,
      _tryGoldAPI,
      _tryWebScraping,
      _tryFallbackPrice,
    ];

    for (final api in apis) {
      try {
        final price = await api();
        if (price != null && price > 0) {
          setState(() {
            _silverPrice = price;
            _isLoading = false;
          });
          await _cachePrice(price); // 가격 캐시 저장
          return;
        }
      } catch (e) {
        continue; // 다음 API 시도
      }
    }

    // 모든 API 실패 시
    setState(() {
      _error = '데이터 없음';
      _isLoading = false;
    });
  }

  // Yahoo Finance (무료, API 키 불필요)
  Future<double?> _tryYahooFinance() async {
    try {
      // 여러 Yahoo Finance 엔드포인트 시도
      final urls = [
        'https://query1.finance.yahoo.com/v8/finance/chart/SI=F',
        'https://query1.finance.yahoo.com/v8/finance/chart/XAGUSD=X',
        'https://query1.finance.yahoo.com/v8/finance/chart/SIL',
      ];
      
      for (final url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          );
          
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
          continue; // 다음 URL 시도
        }
      }
    } catch (e) {
      // Yahoo Finance error
    }
    return null;
  }

  // TwelveData (기존 API 키 사용)
  Future<double?> _tryTwelveData() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.twelvedata.com/price?symbol=XAG/USD&apikey=105c740ebca44e2ba687cfe806fa6b98'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final price = data['price'];
        return price != null ? double.tryParse(price.toString()) : null;
      }
    } catch (e) {
      // TwelveData error
    }
    return null;
  }

  // GoldAPI.io (기존 API 키 사용)
  Future<double?> _tryGoldAPI() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.goldapi.io/api/XAG/USD'),
        headers: {
          'x-access-token': 'goldapi-1rjbsmdcfc6a2-io',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['price']?.toDouble();
      }
    } catch (e) {
      // GoldAPI error
    }
    return null;
  }

  // 웹 스크래핑 (마지막 대안)
  Future<double?> _tryWebScraping() async {
    try {
      // Investing.com에서 은 가격 스크래핑
      final response = await http.get(
        Uri.parse('https://www.investing.com/commodities/silver'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final html = response.body;
        // 간단한 정규식으로 가격 추출 (실제로는 더 정교한 파싱 필요)
        final regex = RegExp(r'data-test="instrument-price-last"[^>]*>([0-9.]+)');
        final match = regex.firstMatch(html);
        if (match != null) {
          return double.tryParse(match.group(1)!);
        }
      }
    } catch (e) {
      // Web scraping error
    }
    return null;
  }

  // Simple API (무료, API 키 불필요)
  Future<double?> _trySimpleAPI() async {
    try {
      // 여러 무료 API 시도
      final urls = [
        'https://api.metals.live/v1/spot/silver',
        'https://api.coinbase.com/v2/exchange-rates?currency=XAG',
        'https://api.exchangerate-api.com/v4/latest/XAG',
      ];
      
      for (final url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          );
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            // 다양한 응답 형식 처리
            double? price;
            if (data['price'] != null) {
              price = data['price'].toDouble();
            } else if (data['data']?['rates']?['USD'] != null) {
              price = 1.0 / data['data']['rates']['USD'].toDouble(); // XAG to USD
            } else if (data['rates']?['USD'] != null) {
              price = 1.0 / data['rates']['USD'].toDouble(); // XAG to USD
            }
            
            if (price != null && price > 0) {
              return price;
            }
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      // Simple API error
    }
    return null;
  }

  // Fixer.io API (무료, API 키 불필요)
  Future<double?> _tryFixerIO() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fixer.io/latest?base=XAG&symbols=USD'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['rates']?['USD'];
        if (rate != null) {
          return 1.0 / rate.toDouble(); // XAG to USD
        }
      }
    } catch (e) {
      // Fixer.io error
    }
    return null;
  }

  // 폴백 가격 (모든 API 실패 시 대체값)
  Future<double?> _tryFallbackPrice() async {
    // 최근 은 가격 대략값 (2024년 기준)
    return 24.50; // USD per ounce
  }

  @override
  Widget build(BuildContext context) {
    const double krwPerUsd = 1383.66; // 환율
    const double ozToDon = 1 / 7.5599; // 1 oz ≒ 7.5599 돈

    double? krwPerDon;
    if (_silverPrice != null) {
      krwPerDon = _silverPrice! * krwPerUsd * ozToDon;
    }

    return Card(
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 80,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Silver (XAG/USD)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '\$${_silverPrice!.toStringAsFixed(2)} / oz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (krwPerDon != null)
                          Text(
                            '약 ${krwPerDon.toStringAsFixed(0)}KRW / 돈',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}
