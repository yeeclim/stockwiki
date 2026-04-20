import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/exchange_rate_service.dart';

class UsdKrwWidget extends StatefulWidget {
  const UsdKrwWidget({super.key});

  @override
  State<UsdKrwWidget> createState() => _UsdKrwWidgetState();
}

class _UsdKrwWidgetState extends State<UsdKrwWidget> {
  double? _usdKrw;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsdKrw();
  }

  Future<void> _fetchUsdKrw() async {
    try {
      final rate = await ExchangeRateService.getUsdToKrw();
      if (mounted) {
        setState(() {
          if (rate != null) {
            _usdKrw = rate;
            _isLoading = false;
          } else {
            _error = '데이터 없음';
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '데이터 로드 실패';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = Colors.indigo;

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
                    Icons.currency_exchange,
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'USD/KRW',
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
                    '₩${_usdKrw!.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    '원',
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
