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
      code: json['code'],
      name: json['name'],
      market: json['market'],
      listedDate: json['listed_date'],
      parValue: json['par_value'],
      closePrice: json['close_price'],
      change: json['change'],
      changeRate: (json['change_rate'] ?? 0).toDouble(),
      openPrice: json['open_price'],
      highPrice: json['high_price'],
      lowPrice: json['low_price'],
      volume: json['volume'],
      marketCap: json['market_cap'],
    );
  }
}
