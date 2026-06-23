import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/portfolio_service.dart';
import '../utils/tradingview_helper.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  List<PortfolioHolding> _holdings = [];
  final Map<String, double> _currentPrices = {};
  bool _isLoading = true;
  bool _isFetchingPrices = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _holdings = await PortfolioService.getAll();
    if (!mounted) return;
    setState(() => _isLoading = false);
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    if (_holdings.isEmpty) return;
    setState(() => _isFetchingPrices = true);

    final krCodes = _holdings
        .where((h) => h.market == 'kr')
        .map((h) => h.stockCode)
        .toList();
    final usTickers = _holdings
        .where((h) => h.market == 'us')
        .map((h) => h.stockCode)
        .toList();

    await Future.wait([
      if (krCodes.isNotEmpty) _fetchKrPrices(krCodes),
      if (usTickers.isNotEmpty) _fetchUsPrices(usTickers),
    ]);

    if (mounted) setState(() => _isFetchingPrices = false);
  }

  Future<void> _fetchKrPrices(List<String> codes) async {
    for (final code in codes) {
      try {
        final url =
            'https://fchart.stock.naver.com/sise.nhn?symbol=$code&timeframe=day&count=2&requestType=0';
        final res = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://finance.naver.com/',
        }).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final matches =
              RegExp(r'data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|')
                  .allMatches(res.body)
                  .toList();
          if (matches.isNotEmpty) {
            final price = double.tryParse(matches.last.group(1) ?? '');
            if (price != null && price > 0) {
              _currentPrices[code] = price;
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchUsPrices(List<String> tickers) async {
    try {
      final origin = Uri.base.origin;
      final symbols = tickers.join(',');
      final res = await http
          .get(
            Uri.parse('$origin/api/us-quote?symbols=$symbols'),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['data'] is List) {
          for (final q in data['data'] as List) {
            final sym = q['symbol'] as String?;
            final price = (q['price'] as num?)?.toDouble();
            if (sym != null && price != null) _currentPrices[sym] = price;
          }
        }
      }
    } catch (_) {
      // FMP 직접 호출 fallback — client-side에서만 가능
    }
  }

  Future<void> _delete(PortfolioHolding holding) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${holding.stockName} 을(를) 포트폴리오에서 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await PortfolioService.remove(holding.stockCode);
      if (!mounted) return;
      _load();
    }
  }

  String _fmtPrice(double price, String market) {
    if (market == 'kr') {
      return '₩${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double totalBuy = 0;
    double totalCurrent = 0;
    for (final h in _holdings) {
      totalBuy += h.totalBuyAmount;
      final cur = _currentPrices[h.stockCode];
      totalCurrent += (cur ?? h.buyPrice) * h.quantity;
    }
    final totalPnl = totalCurrent - totalBuy;
    final totalPnlPct = totalBuy > 0 ? (totalPnl / totalBuy * 100) : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        title: Text('💼 내 포트폴리오',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isFetchingPrices)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.colorScheme.primary)),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
              onPressed: _fetchPrices,
              tooltip: '시세 새로고침',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : _holdings.isEmpty
              ? _buildEmpty(theme)
              : Column(
                  children: [
                    _buildSummary(
                        theme, totalBuy, totalCurrent, totalPnl, totalPnlPct),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: theme.colorScheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _holdings.length,
                          itemBuilder: (ctx, i) =>
                              _buildCard(theme, _holdings[i]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('포트폴리오가 비어있습니다',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('추천 종목 카드에서 + 버튼으로 추가하세요',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme, double totalBuy, double totalCurrent,
      double totalPnl, double totalPnlPct) {
    final isProfit = totalPnl >= 0;
    final pnlColor = isProfit ? Colors.red : Colors.blue;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('총 보유 ${_holdings.length}종목',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('총 매입금액',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  Text(
                    totalBuy < 10000
                        ? '\$${totalBuy.toStringAsFixed(2)}'
                        : '₩${totalBuy.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('평가손익',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  Row(
                    children: [
                      Icon(
                        isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: pnlColor,
                        size: 20,
                      ),
                      Text(
                        '${isProfit ? '+' : ''}${totalPnlPct.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: pnlColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (_isFetchingPrices)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('시세 업데이트 중...',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(ThemeData theme, PortfolioHolding h) {
    final curPrice = _currentPrices[h.stockCode];
    final hasCur = curPrice != null;
    final pnl = hasCur ? (curPrice - h.buyPrice) * h.quantity : 0.0;
    final pnlPct = hasCur && h.buyPrice > 0
        ? (curPrice - h.buyPrice) / h.buyPrice * 100
        : 0.0;
    final isProfit = pnl >= 0;
    final pnlColor = isProfit ? Colors.red : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => showChart(
          context,
          tvSymbol:
              h.market == 'kr' ? krxSymbol(h.stockCode) : usSymbol(h.stockCode),
          stockName: h.stockName,
          naverCode: h.market == 'kr' ? h.stockCode : null,
          yahooTicker: h.market == 'us' ? h.stockCode : null,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.stockName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${h.stockCode} · ${h.market == 'kr' ? '국내' : '미국'} · ${h.quantity % 1 == 0 ? h.quantity.toInt() : h.quantity}주',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => _delete(h),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoCell(theme, '매입단가', _fmtPrice(h.buyPrice, h.market)),
                  const SizedBox(width: 12),
                  _infoCell(theme, '현재가',
                      hasCur ? _fmtPrice(curPrice, h.market) : '-',
                      valueColor: hasCur
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  _infoCell(
                      theme,
                      '평가손익',
                      hasCur
                          ? '${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}%'
                          : '-',
                      valueColor: hasCur
                          ? pnlColor
                          : theme.colorScheme.onSurfaceVariant),
                ],
              ),
              if (hasCur) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}${_fmtPrice(pnl.abs(), h.market)} ${isProfit ? '수익' : '손실'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: pnlColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCell(ThemeData theme, String label, String value,
      {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? theme.colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
