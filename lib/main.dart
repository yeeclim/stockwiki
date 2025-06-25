import 'package:flutter/material.dart';
import 'pages/keyword_search_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockWiki',
      theme: ThemeData.dark(),
      home: const KeywordSearchPage(),
    );
  }
}
