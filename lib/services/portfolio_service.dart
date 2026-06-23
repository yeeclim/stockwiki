import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PortfolioHolding {
  final String stockCode;
  final String stockName;
  final double buyPrice;
  final double quantity;
  final String market; // 'kr' or 'us'
  final DateTime addedAt;

  PortfolioHolding({
    required this.stockCode,
    required this.stockName,
    required this.buyPrice,
    required this.quantity,
    required this.market,
    required this.addedAt,
  });

  double get totalBuyAmount => buyPrice * quantity;

  Map<String, dynamic> toJson() => {
        'stockCode': stockCode,
        'stockName': stockName,
        'buyPrice': buyPrice,
        'quantity': quantity,
        'market': market,
        'addedAt': addedAt.toIso8601String(),
      };

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) =>
      PortfolioHolding(
        stockCode: json['stockCode'],
        stockName: json['stockName'],
        buyPrice: (json['buyPrice'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        market: json['market'] ?? 'kr',
        addedAt: DateTime.parse(json['addedAt']),
      );
}

class PortfolioService {
  static const _key = 'portfolio_holdings';

  static Future<List<PortfolioHolding>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => PortfolioHolding.fromJson(e)).toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (e) {
      debugPrint('포트폴리오 로드 오류: $e');
      return [];
    }
  }

  static Future<void> add(PortfolioHolding holding) async {
    final all = await getAll();
    // 같은 종목이 있으면 수량 합산
    final existing = all.indexWhere((h) => h.stockCode == holding.stockCode);
    if (existing >= 0) {
      final old = all[existing];
      final totalCost = old.totalBuyAmount + holding.totalBuyAmount;
      final newQty = old.quantity + holding.quantity;
      all[existing] = PortfolioHolding(
        stockCode: old.stockCode,
        stockName: old.stockName,
        buyPrice: totalCost / newQty,
        quantity: newQty,
        market: old.market,
        addedAt: old.addedAt,
      );
    } else {
      all.insert(0, holding);
    }
    await _save(all);
  }

  static Future<void> remove(String stockCode) async {
    final all = await getAll();
    all.removeWhere((h) => h.stockCode == stockCode);
    await _save(all);
  }

  static Future<bool> contains(String stockCode) async {
    final all = await getAll();
    return all.any((h) => h.stockCode == stockCode);
  }

  static Future<void> _save(List<PortfolioHolding> holdings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, json.encode(holdings.map((h) => h.toJson()).toList()));
  }
}
