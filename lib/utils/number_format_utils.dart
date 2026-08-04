/// Formats [value] with thousand-separator commas, keeping [decimals] digits
/// after the decimal point (0 by default).
String formatWithCommas(num value, {int decimals = 0}) {
  final isNegative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart =
      parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final result = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return isNegative ? '-$result' : result;
}
