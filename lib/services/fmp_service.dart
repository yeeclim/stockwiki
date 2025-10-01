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
      print('🔍 [FMP] 검색 시작: $keyword');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 웹에서 CORS 문제 해결을 위한 프록시 사용
      final searchUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/search?query=$keyword&limit=10&apikey=$_apiKey&t=$timestamp');
      
      print('🌐 [FMP] 검색 URL: $searchUrl');
      print('📱 [FMP] 웹 모드: $kIsWeb');
      
      final searchRes = await http.get(searchUrl);
      print('📊 [FMP] 검색 응답 상태: ${searchRes.statusCode}');
      print('📄 [FMP] 검색 응답 본문: ${searchRes.body}');

      if (searchRes.statusCode != 200) {
        print('❌ [FMP] 검색 실패 - 상태 코드: ${searchRes.statusCode}');
        throw Exception('검색 실패: ${searchRes.statusCode}');
      }

      final searchData = json.decode(searchRes.body);
      print('📋 [FMP] 검색 데이터 파싱 완료: ${searchData.runtimeType}');
      
      if (searchData is! List || searchData.isEmpty) {
        print('⚠️ [FMP] 검색 결과가 비어있음');
        return [];
      }

      // 미국 주식만 필터링 (무료 플랜 제한)
      List<String> symbols = searchData
          .where((e) => e['exchangeShortName'] == 'NASDAQ' || 
                       e['exchangeShortName'] == 'NYSE' ||
                       e['exchangeShortName'] == 'AMEX')
          .map<String>((e) => e['symbol'] as String)
          .toList();
      print('🏷️ [FMP] 추출된 심볼들 (미국 주식만): $symbols');
      
      if (symbols.isEmpty) {
        print('⚠️ [FMP] 미국 주식이 없음');
        return [];
      }

      // 심볼 기반으로 실시간 정보 조회
      final quoteUrl = kIsWeb 
        ? Uri.parse('$_corsProxy${Uri.encodeComponent('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp')}')
        : Uri.parse('$_baseUrl/quote/${symbols.join(',')}?apikey=$_apiKey&t=$timestamp');
      
      print('💰 [FMP] 시세 URL: $quoteUrl');
      final quoteRes = await http.get(quoteUrl);
      print('📊 [FMP] 시세 응답 상태: ${quoteRes.statusCode}');
      print('📄 [FMP] 시세 응답 본문: ${quoteRes.body}');

      if (quoteRes.statusCode != 200) {
        print('❌ [FMP] 시세 조회 실패 - 상태 코드: ${quoteRes.statusCode}');
        throw Exception('시세 조회 실패: ${quoteRes.statusCode}');
      }

      final quoteData = json.decode(quoteRes.body);
      print('📋 [FMP] 시세 데이터 파싱 완료: ${quoteData.runtimeType}');
      
      if (quoteData is! List) {
        print('⚠️ [FMP] 시세 데이터가 리스트가 아님');
        return [];
      }

      List<Stock> stocks = quoteData
          .map<Stock>((item) => Stock.fromJson(item))
          .toList();
      
      print('✅ [FMP] 최종 결과: ${stocks.length}개 주식');
      return stocks;
    } catch (e) {
      print('💥 [FMP] 전체 오류: $e');
      print('📚 [FMP] 오류 타입: ${e.runtimeType}');
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
