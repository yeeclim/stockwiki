import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ChartScraperService {
  static const String _corsProxy = 'https://api.codetabs.com/v1/proxy?quest=';

  /// Yahoo Finance에서 차트 이미지 스크랩
  static Future<String?> getYahooChartImage(String symbol) async {
    try {
      debugPrint('📊 [Chart Scraper] Yahoo 차트 이미지 스크랩 시작: $symbol');
      
      // 여러 Yahoo Finance 차트 이미지 URL 시도
      final chartUrls = [
        'https://chart.finance.yahoo.com/v7/finance/chart/$symbol?range=1d&interval=1d&width=400&height=300',
        'https://chart.yahoo.com/z?s=$symbol&t=1m&q=l&l=on&z=l&a=v&p=s&lang=en-US&region=US&.tsrc=fin-srch',
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1mo',
        'https://chart.yahoo.com/z?s=$symbol&t=1m&q=l&l=on&z=l&a=v&p=s&lang=en-US&region=US',
      ];
      
      // 첫 번째 URL 사용
      final chartUrl = chartUrls[0];
      
      if (kIsWeb) {
        // 웹에서는 CORS 프록시 사용
        final proxyUrl = '$_corsProxy${Uri.encodeComponent(chartUrl)}';
        debugPrint('🌐 [Chart Scraper] 프록시 URL: $proxyUrl');
        return proxyUrl;
      } else {
        // 모바일/데스크톱에서는 직접 접근
        return chartUrl;
      }
    } catch (e) {
      debugPrint('❌ [Chart Scraper] Yahoo 차트 스크랩 실패: $e');
      return null;
    }
  }

  /// TradingView에서 차트 스크랩 (웹뷰용)
  static String getTradingViewChartUrl(String symbol) {
    return 'https://www.tradingview.com/chart/?symbol=$symbol';
  }

  /// MarketWatch에서 차트 스크랩 (웹뷰용)
  static String getMarketWatchChartUrl(String symbol) {
    return 'https://www.marketwatch.com/investing/stock/${symbol.toLowerCase()}';
  }

  /// Google Finance에서 차트 스크랩 (웹뷰용)
  static String getGoogleFinanceChartUrl(String symbol) {
    return 'https://www.google.com/finance/quote/$symbol:NASDAQ';
  }

  /// Finviz에서 차트 스크랩 (웹뷰용)
  static String getFinvizChartUrl(String symbol) {
    return 'https://finviz.com/quote.ashx?t=$symbol';
  }

  /// Investing.com에서 차트 스크랩 (웹뷰용)
  static String getInvestingChartUrl(String symbol) {
    return 'https://www.investing.com/equities/${symbol.toLowerCase()}-chart';
  }

  /// 차트 이미지가 실제로 로드되는지 테스트
  static Future<bool> testChartImage(String imageUrl) async {
    try {
      debugPrint('🧪 [Chart Scraper] 차트 이미지 테스트: $imageUrl');
      
      final response = await http.head(Uri.parse(imageUrl));
      final isSuccess = response.statusCode == 200;
      
      debugPrint('📊 [Chart Scraper] 테스트 결과: ${isSuccess ? "성공" : "실패"} (${response.statusCode})');
      return isSuccess;
    } catch (e) {
      debugPrint('❌ [Chart Scraper] 테스트 실패: $e');
      return false;
    }
  }

  /// 여러 차트 소스에서 사용 가능한 차트 찾기
  static Future<Map<String, String>> getAvailableCharts(String symbol) async {
    final charts = <String, String>{};
    
    try {
      debugPrint('🔍 [Chart Scraper] 사용 가능한 차트 찾기: $symbol');
      
      // Yahoo 차트 이미지 테스트
      final yahooImage = await getYahooChartImage(symbol);
      if (yahooImage != null) {
        final isWorking = await testChartImage(yahooImage);
        if (isWorking) {
          charts['yahoo_image'] = yahooImage;
          debugPrint('✅ [Chart Scraper] Yahoo 차트 이미지 사용 가능');
        }
      }
      
      // 다른 차트 이미지 서비스들 시도
      final otherCharts = {
        'alpha_vantage': 'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&apikey=demo&datatype=csv',
        'iex_cloud': 'https://cloud.iexapis.com/stable/stock/$symbol/chart/1m?token=demo',
        'finnhub': 'https://finnhub.io/api/v1/quote?symbol=$symbol&token=demo',
        'polygon': 'https://api.polygon.io/v2/aggs/ticker/$symbol/prev?adjusted=true&apikey=demo',
      };
      
      // 웹뷰용 차트들 추가
      charts['tradingview'] = getTradingViewChartUrl(symbol);
      charts['marketwatch'] = getMarketWatchChartUrl(symbol);
      charts['google_finance'] = getGoogleFinanceChartUrl(symbol);
      charts['finviz'] = getFinvizChartUrl(symbol);
      charts['investing'] = getInvestingChartUrl(symbol);
      
      // 차트 이미지가 없는 경우 간단한 차트 위젯 표시
      if (charts.isEmpty) {
        charts['simple_chart'] = 'simple_chart';
        debugPrint('⚠️ [Chart Scraper] 차트 이미지 없음, 간단한 차트 위젯 사용');
      }
      
      debugPrint('📊 [Chart Scraper] 총 ${charts.length}개 차트 소스 준비 완료');
      return charts;
    } catch (e) {
      debugPrint('❌ [Chart Scraper] 차트 소스 준비 실패: $e');
      // 오류가 발생해도 기본 차트는 제공
      charts['simple_chart'] = 'simple_chart';
      return charts;
    }
  }
}
