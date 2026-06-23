class KrxFullStock {
  final String code;
  final String name;
  final String market;
  final String listedDate;
  final String parValue;
  final int closePrice;
  final int change;
  final double changeRate;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
  final int marketCap;

  KrxFullStock({
    required this.code,
    required this.name,
    required this.market,
    required this.listedDate,
    required this.parValue,
    required this.closePrice,
    required this.change,
    required this.changeRate,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.marketCap,
  });

  factory KrxFullStock.fromJson(Map<String, dynamic> json) {
    return KrxFullStock(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      market: (json['market'] as String?) ?? '',
      listedDate: (json['listed_date'] as String?) ?? '',
      parValue: (json['par_value'] as String?) ?? '',
      closePrice: (json['close_price'] as num?)?.toInt() ?? 0,
      change: (json['change'] as num?)?.toInt() ?? 0,
      changeRate: (json['change_rate'] as num?)?.toDouble() ?? 0.0,
      openPrice: (json['open_price'] as num?)?.toInt() ?? 0,
      highPrice: (json['high_price'] as num?)?.toInt() ?? 0,
      lowPrice: (json['low_price'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      marketCap: (json['market_cap'] as num?)?.toInt() ?? 0,
    );
  }
}
