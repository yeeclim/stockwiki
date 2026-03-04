import 'package:flutter/foundation.dart';
void main() {
  String widgetSymbol = 'DDOG';
  String periodParam = 'd';
  bool isKorean = false;
  
  String baseUrl = 'https://stockwiki.vercel.app';
  bool isLocalDev = false;
  final apiBaseUrl = isLocalDev ? 'http://localhost:3000' : baseUrl;
  final timestamp = 123456789;
  
  final url = '$apiBaseUrl/api/chart-proxy?symbol=$widgetSymbol&period=$periodParam&isKorean=$isKorean&cb=$timestamp';
  print(url);
}
