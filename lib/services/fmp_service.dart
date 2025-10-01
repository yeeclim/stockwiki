import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../models/news.dart';

class FMPService {
  static const String _apiKey = '0Zuh2twrNdDI5HsaBnG9jeSU3d1UNCEh'; // 실제 키로 교체
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';
  static const String _corsProxy = 'https://api.codetabs.com/v1/proxy?quest=';

  /// 키워드 기반 검색 후 실시간 가격 정보 추가
  static Future<List<Stock>> fetchStocks(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 웹에서 CORS 문제 해결을 위한 프록시 사용
      final searchUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp');
      
      final searchRes = await http.get(searchUrl);

      if (searchRes.statusCode != 200) throw Exception('검색 실패');

      final searchData = json.decode(searchRes.body);
      if (searchData is! List || searchData.isEmpty) return [];

      List<String> symbols = searchData
          .map<String>((e) => e['symbol'] as String)
          .toList();

      // 심볼 기반으로 실시간 정보 조회
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp');
      final quoteRes = await http.get(quoteUrl);

      if (quoteRes.statusCode != 200) throw Exception('시세 조회 실패');

      final quoteData = json.decode(quoteRes.body);
      if (quoteData is! List) return [];

      List<Stock> stocks = quoteData
          .map<Stock>((item) => Stock.fromJson(item))
          .toList();

      return stocks;
    } catch (e) {
      print('Error fetching stocks: $e');
      return [];
    }
  }

  /// 단일 주식 상세 정보 조회 (차트용)
  static Future<Map<String, dynamic>?> fetchStockDetail(String symbol) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/$symbol?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(quoteUrl);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0];
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 주식 관련 뉴스 조회
  static Future<List<News>> fetchStockNews(String symbol) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newsUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/stock_news?tickers=$symbol&limit=10&apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/stock_news?tickers=$symbol&limit=10&apikey=$_apiKey&t=$timestamp');
      
      final response = await http.get(newsUrl);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      if (data is List) {
        return data.map((item) => News.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Yahoo Finance 차트 데이터 가져오기 (대체 방법)
  static Future<String?> getYahooChartUrl(String symbol) async {
    try {
      // Yahoo Finance 차트 이미지 URL 생성
      return 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1mo';
    } catch (e) {
      return null;
    }
  }
}
