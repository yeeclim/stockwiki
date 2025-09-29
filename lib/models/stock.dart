// lib/models/stock.dart

import 'news.dart';

class Stock {
  final String symbol;
  final String name;
  final double? price;
  final double? change;
  final double? changePercent;
  final int? volume;
  final int? marketCap;
  final String? lastUpdate;
  final List<News>? news;

  Stock({
    required this.symbol,
    required this.name,
    this.price,
    this.change,
    this.changePercent,
    this.volume,
    this.marketCap,
    this.lastUpdate,
    this.news,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    List<News>? newsList;
    if (json['news'] != null) {
      final newsData = json['news'] as List<dynamic>;
      newsList = newsData.map((item) => News.fromJson(item)).toList();
    }
    
    return Stock(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      price: json['price']?.toDouble(),
      change: json['change']?.toDouble(),
      changePercent: json['changePercent']?.toDouble(),
      volume: json['volume']?.toInt(),
      marketCap: json['marketCap']?.toInt(),
      lastUpdate: json['lastUpdate'],
      news: newsList,
    );
  }

  // KRX 데이터에서 Stock 객체 생성
  factory Stock.fromKrxData(Map<String, dynamic> krxData) {
    return Stock(
      symbol: krxData['단축코드']?.toString() ?? krxData['code']?.toString() ?? '',
      name: krxData['한글 종목명']?.toString() ?? krxData['name']?.toString() ?? '',
      price: krxData['price']?.toDouble(),
      change: krxData['change']?.toDouble(),
      changePercent: krxData['changePercent']?.toDouble(),
      volume: krxData['volume']?.toInt(),
      marketCap: krxData['marketCap']?.toInt(),
      lastUpdate: krxData['lastUpdate'],
      news: null, // KRX 데이터에는 뉴스 정보가 없음
    );
  }
}
