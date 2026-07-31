import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bookmark_service.dart';
import '../widgets/tradingview_chart.dart';

/// 한국 종목 코드 → TradingView KRX 심볼
String krxSymbol(String code) => 'KRX:$code';

/// 미국 티커 → TradingView 거래소:티커
String usSymbol(String ticker) {
  const nyse = {
    'JPM',
    'V',
    'MA',
    'BAC',
    'BLK',
    'XOM',
    'CVX',
    'WMT',
    'KO',
    'PG',
    'COP',
    'SLB',
    'NEE',
    'UNH',
    'JNJ',
    'MRK',
    'LLY',
    'NVO',
    'AMZN',
    'COST',
    'ACN',
    'TMO',
    'ABBV',
    'PEP',
    'HD',
    'MCD',
    'CAT',
    'GS',
    'AXP',
  };
  const nasdaq = {
    'AAPL',
    'MSFT',
    'NVDA',
    'GOOGL',
    'GOOG',
    'META',
    'TSLA',
    'AVGO',
    'AMD',
    'NFLX',
    'CRM',
    'ORCL',
    'QCOM',
    'ADBE',
    'INTC',
    'CSCO',
  };
  if (nyse.contains(ticker)) return 'NYSE:$ticker';
  if (nasdaq.contains(ticker)) return 'NASDAQ:$ticker';
  return ticker;
}

/// TradingView 차트 바텀시트 표시
void showChart(
  BuildContext context, {
  required String tvSymbol,
  required String stockName,
  String? naverCode,
  String? yahooTicker,
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
      final code =
          naverCode ?? tvSymbol.replaceFirst(RegExp(r'^[A-Za-z]+:'), '');
      final isKrx = tvSymbol.startsWith('KRX:');
      final isAlphanumeric =
          isKrx && !RegExp(r'^\d{6}$').hasMatch(tvSymbol.substring(4));

      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        child: Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: th.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 타이틀 + 관심종목 + 외부 링크
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stockName,
                            style: th.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(tvSymbol,
                            style: th.textTheme.bodySmall?.copyWith(
                                color: th.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _ChartBookmarkButton(
                    stockCode: code,
                    stockName: stockName,
                    market: isKrx ? 'kr' : 'us',
                  ),
                  if (naverCode != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                            'https://finance.naver.com/item/main.naver?code=$naverCode'),
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
                        Uri.parse(
                            'https://finance.yahoo.com/quote/$yahooTicker'),
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
            // 차트 영역
            Expanded(
              child: isAlphanumeric
                  ? _buildNewListingPanel(ctx, code)
                  : isKrx
                      ? _NaverChartWidget(code: code)
                      : TradingViewChart(tvSymbol: tvSymbol, isDark: isDark),
            ),
          ],
        ),
      );
    },
  );
}

// ── 관심종목 등록 버튼 (차트 바텀시트) ────────────────────────────────────────
class _ChartBookmarkButton extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final String market; // 'kr' | 'us'

  const _ChartBookmarkButton({
    required this.stockCode,
    required this.stockName,
    required this.market,
  });

  @override
  State<_ChartBookmarkButton> createState() => _ChartBookmarkButtonState();
}

class _ChartBookmarkButtonState extends State<_ChartBookmarkButton> {
  bool _isBookmarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final result = await BookmarkService.isBookmarked(widget.stockCode);
    if (mounted)
      setState(() {
        _isBookmarked = result;
        _isLoading = false;
      });
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkService.removeBookmark(widget.stockCode);
    } else {
      await BookmarkService.addBookmark(widget.stockCode, {
        'stockName': widget.stockName,
        'symbol': widget.stockCode,
        'type': widget.market,
      });
    }
    await _checkBookmark();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isBookmarked ? '관심종목에 추가되었습니다' : '관심종목에서 제거되었습니다'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(width: 40, height: 40);
    return IconButton(
      icon: Icon(
        _isBookmarked ? Icons.star : Icons.star_border,
        color: _isBookmarked ? Colors.amber.shade600 : null,
      ),
      onPressed: _toggleBookmark,
      tooltip: _isBookmarked ? '관심종목 제거' : '관심종목 추가',
    );
  }
}

// ── 네이버 차트 이미지 위젯 ────────────────────────────────────────────────────
class _NaverChartWidget extends StatefulWidget {
  final String code;
  const _NaverChartWidget({required this.code});

  @override
  State<_NaverChartWidget> createState() => _NaverChartWidgetState();
}

class _NaverChartWidgetState extends State<_NaverChartWidget> {
  String _period = 'd';
  bool _hasError = false;

  String get _url {
    final origin = kIsWeb ? Uri.base.origin : 'https://stockwiki.vercel.app';
    return '$origin/api/utils?type=chart&symbol=${widget.code}&isKorean=true&period=$_period';
  }

  void _changePeriod(String p) => setState(() {
        _period = p;
        _hasError = false;
      });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Column(
      children: [
        // 기간 선택
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final pair in [('일', 'd'), ('주', 'w'), ('월', 'm')])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(pair.$1),
                    selected: _period == pair.$2,
                    onSelected: (_) => _changePeriod(pair.$2),
                  ),
                ),
            ],
          ),
        ),
        // 차트 이미지
        Expanded(
          child: _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 40,
                          color:
                              th.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('차트를 불러올 수 없습니다.',
                          style: th.textTheme.bodyMedium?.copyWith(
                              color: th.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(
                              'https://finance.naver.com/item/main.naver?code=${widget.code}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('네이버에서 보기'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Image.network(
                    _url,
                    key: ValueKey(_url),
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Center(
                            child: CircularProgressIndicator(
                            color: th.colorScheme.primary,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          )),
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _hasError = true);
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ── 신규상장·알파뉴메릭 코드 안내 패널 ─────────────────────────────────────────
Widget _buildNewListingPanel(BuildContext ctx, String code) {
  final th = Theme.of(ctx);
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 56,
              color: th.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text('차트 데이터 준비 중',
              style: th.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            '신규 상장 종목($code)으로\n차트 데이터가 아직 없습니다.\n아래 링크에서 확인하세요.',
            textAlign: TextAlign.center,
            style: th.textTheme.bodySmall
                ?.copyWith(color: th.colorScheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 28),
          _linkButton(ctx,
              icon: Icons.show_chart,
              label: '네이버 증권에서 보기',
              color: const Color(0xFF03C75A),
              url: 'https://finance.naver.com/item/main.naver?code=$code'),
          const SizedBox(height: 12),
          _linkButton(ctx,
              icon: Icons.account_balance,
              label: 'KRX 한국거래소에서 보기',
              color: const Color(0xFF1A6FE8),
              url: 'https://www.krx.co.kr/main/main.jsp'),
        ],
      ),
    ),
  );
}

Widget _linkButton(
  BuildContext ctx, {
  required IconData icon,
  required String label,
  required Color color,
  required String url,
}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: Icon(icon, size: 18, color: color),
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
