import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/portfolio_service.dart';

Future<bool> showPortfolioAddSheet(
  BuildContext context, {
  required String stockCode,
  required String stockName,
  required String market,
  double? currentPrice,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PortfolioAddSheet(
      stockCode: stockCode,
      stockName: stockName,
      market: market,
      currentPrice: currentPrice,
    ),
  );
  return result == true;
}

class _PortfolioAddSheet extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final String market;
  final double? currentPrice;

  const _PortfolioAddSheet({
    required this.stockCode,
    required this.stockName,
    required this.market,
    this.currentPrice,
  });

  @override
  State<_PortfolioAddSheet> createState() => _PortfolioAddSheetState();
}

class _PortfolioAddSheetState extends State<_PortfolioAddSheet> {
  late final TextEditingController _priceCtrl;
  final _qtyCtrl = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.currentPrice != null
          ? widget.currentPrice!.toStringAsFixed(widget.market == 'us' ? 2 : 0)
          : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', ''));
    final qty = double.tryParse(_qtyCtrl.text);
    if (price == null || price <= 0) {
      _showError('매입단가를 입력해주세요');
      return;
    }
    if (qty == null || qty <= 0) {
      _showError('수량을 입력해주세요');
      return;
    }
    setState(() => _saving = true);
    await PortfolioService.add(PortfolioHolding(
      stockCode: widget.stockCode,
      stockName: widget.stockName,
      buyPrice: price,
      quantity: qty,
      market: widget.market,
      addedAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKr = widget.market == 'kr';
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('포트폴리오 추가',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${widget.stockName} (${widget.stockCode})',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Text('매입단가 (${isKr ? '원' : 'USD'})',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
            ],
            decoration: InputDecoration(
              hintText: isKr ? '예: 85000' : '예: 150.00',
              prefixText: isKr ? '₩ ' : '\$ ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Text('수량 (주)',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            decoration: InputDecoration(
              hintText: '예: 10',
              suffixText: '주',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('추가하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
