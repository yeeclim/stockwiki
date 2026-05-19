import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/tradingview_helper.dart';
import '../widgets/portfolio_add_sheet.dart';

class KrStockSearchPage extends StatefulWidget {
  const KrStockSearchPage({super.key});

  @override
  State<KrStockSearchPage> createState() => _KrStockSearchPageState();
}

class _KrStockSearchPageState extends State<KrStockSearchPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _error = '';
  String _type = 'all'; // 'all' | 'stock' | 'etf'

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() { _isLoading = true; _error = ''; _results = []; });

    try {
      final origin = Uri.base.origin;
      final url = '$origin/api/kr-stock-search?query=${Uri.encodeComponent(q)}&type=$_type';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() => _results = List<Map<String, dynamic>>.from(data['data'] ?? []));
        } else {
          setState(() => _error = data['error'] ?? '검색 실패');
        }
      } else {
        setState(() => _error = '서버 오류 (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = '검색 중 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _fmtPrice(num price) =>
      '₩${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('🇰🇷 국내 검색',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '닫기',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 검색 입력
            TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '종목명 또는 코드 (예: 삼성전자, KODEX, 005930)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
                  onPressed: _search,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // 종류 필터 칩
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('전체', 'all', theme),
                  const SizedBox(width: 8),
                  _filterChip('주식', 'stock', theme),
                  const SizedBox(width: 8),
                  _filterChip('ETF·ETN', 'etf', theme),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 결과
            if (_isLoading)
              Expanded(child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
            else if (_error.isNotEmpty)
              _buildError(theme)
            else if (_results.isEmpty && _controller.text.isNotEmpty)
              _buildEmpty(theme)
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) => _buildCard(theme, _results[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, ThemeData theme) {
    final selected = _type == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _type = value);
        if (_controller.text.isNotEmpty) _search();
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(_error, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _search, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('검색 결과가 없습니다', style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, Map<String, dynamic> item) {
    final code = item['code'] as String? ?? '';
    final name = item['name'] as String? ?? '';
    final isEtf = item['isEtf'] as bool? ?? false;
    final market = item['market'] as String? ?? '';
    final price = item['price'] as num?;
    final changePct = item['changePercent'] as num?;
    final hasChange = changePct != null;
    final isUp = hasChange && changePct! >= 0;
    final changeColor = isUp ? Colors.red : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => showChart(
            context,
            tvSymbol: krxSymbol(code),
            stockName: name,
            naverCode: code,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 아이콘 박스
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isEtf
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      isEtf ? 'E' : name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(
                        color: isEtf
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 이름, 코드, 시장
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isEtf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                code.startsWith('5') ? 'ETN' : 'ETF',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('$code · $market',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),

                // 가격, 등락률
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price != null ? _fmtPrice(price) : '-',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (hasChange) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: changeColor, size: 16,
                          ),
                          Text(
                            '${changePct!.abs().toStringAsFixed(2)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: changeColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),

                // 포트폴리오 버튼
                IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      size: 20, color: theme.colorScheme.secondary),
                  onPressed: () => showPortfolioAddSheet(
                    context,
                    stockCode: code,
                    stockName: name,
                    market: 'kr',
                    currentPrice: price?.toDouble(),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '포트폴리오 추가',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
