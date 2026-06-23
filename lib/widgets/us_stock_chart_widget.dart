import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UsStockChartWidget extends StatefulWidget {
  final String symbol;

  const UsStockChartWidget({
    super.key,
    required this.symbol,
  });

  @override
  State<UsStockChartWidget> createState() => _UsStockChartWidgetState();
}

class _UsStockChartWidgetState extends State<UsStockChartWidget> {
  String _selectedPeriod = 'Daily'; // Intraday, Daily, Weekly, Monthly
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.symbol.isEmpty) {
      setState(() {
        _errorMessage = '유효하지 않은 종목입니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = _getChartUrl();
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '데이터 없음 (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '연결 오류 발생';
        _isLoading = false;
      });
    }
  }

  String _getChartUrl() {
    String periodParam = 'd';
    switch (_selectedPeriod) {
      case 'Intraday':
        periodParam = 'i15';
        break;
      case 'Daily':
        periodParam = 'd';
        break;
      case 'Weekly':
        periodParam = 'w';
        break;
      case 'Monthly':
        periodParam = 'm';
        break;
    }

    // 한국 주식 여부 판별
    final isKorean = RegExp(r'^\d+$').hasMatch(widget.symbol) ||
        widget.symbol.endsWith('.KS') ||
        widget.symbol.endsWith('.KQ') ||
        RegExp(r'[가-힣]').hasMatch(widget.symbol);

    // 환경별 API URL 설정
    String baseUrl = 'https://stockwiki.vercel.app';
    bool isLocalDev = false;
    try {
      if (kIsWeb) {
        baseUrl = Uri.base.origin;
        isLocalDev =
            baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
      }
    } catch (_) {}

    final apiBaseUrl = isLocalDev ? 'http://localhost:3000' : baseUrl;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return '$apiBaseUrl/api/utils?type=chart&symbol=${widget.symbol}&period=$periodParam&isKorean=$isKorean&cb=$timestamp';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: theme.cardTheme.elevation,
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.symbol} 주가 차트',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImageContent(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (_errorMessage != null || _imageBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '차트 이미지를 불러올 수 없습니다.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Intraday', 'Daily', 'Weekly', 'Monthly'];
    final displayNames = {
      'Intraday': '1일',
      'Daily': '일봉',
      'Weekly': '주봉',
      'Monthly': '월봉'
    };
    final theme = Theme.of(context);

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () {
              if (_selectedPeriod != period) {
                setState(() {
                  _selectedPeriod = period;
                });
                _loadImage();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayNames[period]!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
