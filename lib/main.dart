import 'package:flutter/material.dart';

void main() {
  runApp(const StockWikiApp());
}

class StockWikiApp extends StatelessWidget {
  const StockWikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        cardColor: const Color(0xFF2C2C2E),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final List<Map<String, String>> marketData = const [
    {'title': '연방기금금리', 'value': '5.33%', 'change': ''},
    {'title': 'USD 인덱스', 'value': '105.78', 'change': '+0.17%'},
    {'title': '금', 'value': '2,328.10', 'change': '+0.42%'},
    {'title': '은', 'value': '27.05', 'change': '+1.02%'},
    {'title': '구리', 'value': '4.46', 'change': '+1.66%'},
    {'title': '백금', 'value': '948.40', 'change': '+0.19%'},
    {'title': '원유', 'value': '83.16', 'change': '+0.57%'},
    {'title': '비트코인', 'value': '66,421.98', 'change': '-0.35%'},
    {'title': '이더리움', 'value': '3,243.16', 'change': '-0.86%'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockWiki'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: marketData.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final data = marketData[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title']!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['value']!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['change']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: data['change']!.startsWith('-')
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
