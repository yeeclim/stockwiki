import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FedWatchWidget extends StatefulWidget {
  const FedWatchWidget({super.key});

  @override
  State<FedWatchWidget> createState() => _FedWatchWidgetState();
}

class _FedWatchWidgetState extends State<FedWatchWidget> {
  String _text = '로딩 중...';

  @override
  void initState() {
    super.initState();
    _fetchFedWatch();
  }

  Future<void> _fetchFedWatch() async {
    try {
      final response = await http.get(Uri.parse('https://dataneutrino.vercel.app/api/fedwatch'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _text = data['text'] ?? '데이터 없음';
        });
      } else {
        setState(() => _text = '불러오기 실패');
      }
    } catch (e) {
      setState(() => _text = '에러 발생');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.show_chart, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text('Fed : $_text',
              style: const TextStyle(fontSize: 14, color: Colors.white)),
        ],
      ),
    );
  }
}
