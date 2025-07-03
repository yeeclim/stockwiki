import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FearGreedWidget extends StatefulWidget {
  const FearGreedWidget({super.key});

  @override
  State<FearGreedWidget> createState() => _FearGreedWidgetState();
}

class _FearGreedWidgetState extends State<FearGreedWidget> {
  int _indexValue = -1;
  String _label = '로딩 중...';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchIndex();
  }

  Future<void> _fetchIndex() async {
    try {
      final uri = Uri.parse('https://api.alternative.me/fng/?limit=1');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'][0];
        final value = int.parse(data['value']);
        final classification = data['value_classification'];
        setState(() {
          _indexValue = value;
          _label = classification;
        });
      } else {
        setState(() {
          _error = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            _error
                ? 'Fear & Greed : -1 (load failed)'
                : 'Fear & Greed : $_indexValue ($_label)',
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
