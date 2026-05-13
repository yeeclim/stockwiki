import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/tradingview_chart.dart';

// KRX 심볼 중 알파뉴메릭 코드(신규상장 등)만 차트 미지원
// 미국주식(NASDAQ:AAPL 등) 및 일반 KRX 6자리는 차트 지원
bool _hasTvChart(String tvSymbol) {
  if (!tvSymbol.startsWith('KRX:')) return true;
  final code = tvSymbol.substring(4);
  return RegExp(r'^\d{6}$').hasMatch(code);
}

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

Widget _buildNoChart(BuildContext ctx, String tvSymbol, String? naverCode, bool isDark) {
  final th = Theme.of(ctx);
  final code = naverCode ?? tvSymbol.replaceFirst(RegExp(r'^[A-Za-z]+:'), '');

  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 56, color: th.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            '차트 데이터 준비 중',
            style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '신규 상장 종목이거나 특수 코드($code) 종목으로\nTradingView 차트 데이터가 아직 없습니다.\n아래 링크에서 상세 정보를 확인하세요.',
            textAlign: TextAlign.center,
            style: th.textTheme.bodySmall?.copyWith(
              color: th.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          _linkButton(
            ctx,
            icon: Icons.show_chart,
            label: '네이버 증권에서 보기',
            color: const Color(0xFF03C75A),
            url: 'https://finance.naver.com/item/main.naver?code=$code',
          ),
          const SizedBox(height: 12),
          _linkButton(
            ctx,
            icon: Icons.account_balance,
            label: 'KRX 한국거래소에서 보기',
            color: const Color(0xFF1A6FE8),
            url: 'https://www.krx.co.kr/main/main.jsp',
          ),
        ],
      ),
    ),
  );
}

Widget _linkButton(BuildContext ctx, {
  required IconData icon,
  required String label,
  required Color color,
  required String url,
}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
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
              child: _hasTvChart(tvSymbol)
                  ? TradingViewChart(tvSymbol: tvSymbol, isDark: isDark)
                  : _buildNoChart(ctx, tvSymbol, naverCode, isDark),
            ),
          ],
        ),
      );
    },
  );
}
