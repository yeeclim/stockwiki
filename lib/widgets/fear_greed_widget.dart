import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FearGreedWidget extends StatefulWidget {
  const FearGreedWidget({super.key});

  @override
  State<FearGreedWidget> createState() => _FearGreedWidgetState();
}

class _FearGreedWidgetState extends State<FearGreedWidget> {
  int? _indexValue;
  String? _label;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedIndex();
    _fetchIndex();
  }

  // 캐시된 인덱스 로드
  Future<void> _loadCachedIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedValue = prefs.getInt('fear_greed_value');
      final cachedLabel = prefs.getString('fear_greed_label');
      final cacheTime = prefs.getInt('fear_greed_cache_time');
      
      if (cachedValue != null && cachedLabel != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // 30분 이내 캐시된 데이터가 있으면 사용 (Fear & Greed는 자주 변하지 않음)
        if (now - cacheTime < 30 * 60 * 1000) {
          setState(() {
            _indexValue = cachedValue;
            _label = cachedLabel;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 캐시 로드 실패 시 무시
    }
  }

  // 인덱스 캐시 저장
  Future<void> _cacheIndex(int value, String label) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fear_greed_value', value);
      await prefs.setString('fear_greed_label', label);
      await prefs.setInt('fear_greed_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 캐시 저장 실패 시 무시
    }
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
          _isLoading = false;
        });
        await _cacheIndex(value, classification); // 인덱스 캐시 저장
      } else {
        throw Exception('Failed to fetch FNG');
      }
    } catch (e) {
      setState(() {
        _error = '데이터 없음';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade800,
            ],
          ),
        ),
        child: SizedBox(
          height: 80,
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Fear & Greed', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            '$_indexValue ($_label)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
