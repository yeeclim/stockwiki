import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/tradingview_chart.dart';

/// 한국 종목 코드 → TradingView KRX 심볼
String krxSymbol(String code) => 'KRX:$code';

/// 미국 티커 → TradingView 거래소:티커
String usSymbol(String ticker) {
  const nyse = {
    'JPM', 'V',    'MA',   'BAC', 'BLK', 'XOM', 'CVX', 'WMT',
    'KO',  'PG',   'COP',  'SLB', 'NEE', 'UNH', 'JNJ', 'MRK',
    'LLY', 'NVO',  'AMZN', 'COST','ACN', 'TMO', 'ABBV','PEP',
    'HD',  'MCD',  'CAT',  'GS',  'AXP',
  };
  const nasdaq = {
    'AAPL','MSFT','NVDA','GOOGL','GOOG','META','TSLA','AVGO',
    'AMD', 'NFLX','CRM', 'ORCL', 'QCOM','ADBE','INTC','CSCO',
  };
  if (nyse.contains(ticker))    return 'NYSE:$ticker';
  if (nasdaq.contains(ticker))  return 'NASDAQ:$ticker';
  return ticker;
}

/// TradingView 차트 바텀시트 표시
void showChart(
  BuildContext context, {
  required String tvSymbol,
  required String stockName,
  String? naverCode,   // 한국 종목 코드 (네이버 링크용)
  String? yahooTicker, // 미국 티커 (Yahoo 링크용)
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final th = Theme.of(ctx);
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        child: Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: th.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 타이틀 + 외부 링크
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stockName,
                          style: th.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          tvSymbol,
                          style: th.textTheme.bodySmall?.copyWith(
                            color: th.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (naverCode != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://finance.naver.com/item/main.naver?code=$naverCode'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 13),
                      label: const Text('네이버'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (yahooTicker != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://finance.yahoo.com/quote/$yahooTicker'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 13),
                      label: const Text('Yahoo'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 차트
            Expanded(
              child: TradingViewChart(
                tvSymbol: tvSymbol,
                isDark: isDark,
              ),
            ),
          ],
        ),
      );
    },
  );
}
