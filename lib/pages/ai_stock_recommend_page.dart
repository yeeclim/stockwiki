import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/bookmark_service.dart';
import '../widgets/ai_recommend_header.dart';
import '../widgets/ai_recommend_card.dart';
import '../widgets/ai_recommend_empty_state.dart';

class AiStockRecommendPage extends StatefulWidget {
  const AiStockRecommendPage({super.key});

  @override
  State<AiStockRecommendPage> createState() => _AiStockRecommendPageState();
}

class _AiStockRecommendPageState extends State<AiStockRecommendPage> {
  List<StockRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefreshTimer;
  final Set<String> _likedStocks = {};
  final Set<String> _bookmarkedStocks = {};

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadBookmarks();
    _startAutoRefresh();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await BookmarkService.getBookmarkedStocks();
    setState(() {
      _bookmarkedStocks.clear();
      _bookmarkedStocks.addAll(bookmarks);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadRecommendations(silent: true);
      }
    });
  }

  Future<void> _loadRecommendations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final baseUrl = Uri.base.origin;
    final isLocalDev =
        baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

    debugPrint('🌍 환경 정보: ${isLocalDev ? "로컬 개발" : "운영"}');
    debugPrint('🔗 현재 URL: $baseUrl');
    debugPrint('📱 User Agent: ${Uri.base.toString()}');

    if (isLocalDev) {
      debugPrint('🏠 로컬 개발 환경 감지 - API 호출 생략');
      setState(() {
        _isLoading = false;
        _error = null;
        _recommendations = [];
      });
      return;
    }

    try {
      debugPrint('🚀 운영 환경에서 API 호출 시작');
      final result = await _fetchFromAPI();

      debugPrint('✅ API 호출 성공: ${result.recommendations.length}개 추천 받음');
      setState(() {
        _recommendations = result.recommendations;
        _lastUpdated = result.lastUpdated;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 운영 환경 API 호출 실패: $e');
      debugPrint('🔍 에러 타입: ${e.runtimeType}');
      debugPrint('📋 에러 상세: ${e.toString()}');

      if (!silent) {
        setState(() {
          _recommendations = [];
          _isLoading = false;
          _error = 'AI 추천 서비스를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  Future<({List<StockRecommendation> recommendations, DateTime? lastUpdated})>
      _fetchFromAPI() async {
    final baseUrl = Uri.base.origin;
    final url = '$baseUrl/api/ai-recommend-list?limit=20&refresh=true';

    debugPrint('🌐 AI 추천 API 호출 URL: $url');
    debugPrint('📱 현재 도메인: $baseUrl');
    debugPrint('🕐 API 호출 시간: ${DateTime.now().toIso8601String()}');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏰ API 타임아웃 발생 (30초 초과)');
          throw Exception('API 응답 시간 초과 (30초)');
        },
      );

      debugPrint('📊 API 응답 상태: ${response.statusCode}');
      debugPrint('📄 API 응답 헤더: ${response.headers}');
      debugPrint('📄 응답 본문 길이: ${response.body.length}');
      debugPrint(
          '📄 API 응답 본문 (첫 500자): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      if (response.statusCode != 200) {
        debugPrint('❌ HTTP 에러: ${response.statusCode} ${response.reasonPhrase}');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final responseBody = response.body.trim();
      debugPrint(
          '🔍 응답 본문 시작: ${responseBody.substring(0, responseBody.length > 50 ? 50 : responseBody.length)}');

      if (!responseBody.startsWith('{')) {
        debugPrint('❌ JSON 응답이 아님 - HTML 응답 감지');
        debugPrint('📄 전체 응답 본문: $responseBody');
        throw Exception(
            'API가 JSON이 아닌 응답을 반환했습니다: ${responseBody.substring(0, 100)}...');
      }

      debugPrint('✅ JSON 응답 확인됨 - 파싱 시작');
      final data = json.decode(responseBody);
      debugPrint('📊 파싱된 JSON 데이터: ${data.runtimeType}');
      debugPrint('🔑 JSON 키들: ${data is Map ? data.keys.toList() : 'N/A'}');

      if (data is! Map) {
        throw Exception('JSON 응답이 객체가 아닙니다: ${data.runtimeType}');
      }

      if (data['success'] != true) {
        debugPrint('❌ API 응답에서 success=false');
        throw Exception('API 응답 실패: ${data['error'] ?? '알 수 없는 오류'}');
      }

      final results = data['data'] as List<dynamic>? ?? [];
      debugPrint('📋 추천 데이터 개수: ${results.length}');

      if (results.isEmpty) {
        debugPrint('⚠️ 추천 데이터가 비어있음');
      }

      DateTime? lastUpdated;
      if (data['lastUpdated'] != null) {
        try {
          lastUpdated = DateTime.parse(data['lastUpdated']);
        } catch (e) {
          debugPrint('⚠️ lastUpdated 파싱 실패: $e');
        }
      }

      final recommendations = results
          .map((item) => StockRecommendation(
                stockName: item['stockName'] ?? '',
                stockCode: item['stockCode'] ?? '',
                currentPrice: item['currentPrice'] ?? 0,
                changePercent: (item['changePercent'] ?? 0).toDouble(),
                changeAmount: item['changeAmount'] ?? 0,
                previousClose: item['previousClose'],
                priceSource: item['priceSource'],
                action: item['action'] ?? '보유',
                reasons: List<String>.from(item['reasons'] ?? []),
                targetPrice: item['targetPrice'] ?? 0,
                postedAt: DateTime.parse(
                    item['postedAt'] ?? DateTime.now().toIso8601String()),
                likes: item['likes'] ?? 0,
                comments: item['comments'] ?? 0,
                shares: item['shares'] ?? 0,
                dayTrading: item['dayTrading'] != null
                    ? TradingStrategy(
                        buyPrice: item['dayTrading']['buyPrice'] ?? 0,
                        sellPrice: item['dayTrading']['sellPrice'] ?? 0,
                        stopLoss: item['dayTrading']['stopLoss'],
                        period: item['dayTrading']['period'] ?? '',
                        expectedReturn:
                            (item['dayTrading']['expectedReturn'] ?? 0)
                                .toDouble(),
                      )
                    : null,
                swingTrading: item['swingTrading'] != null
                    ? TradingStrategy(
                        buyPrice: item['swingTrading']['buyPrice'] ?? 0,
                        sellPrice: item['swingTrading']['sellPrice'] ?? 0,
                        stopLoss: item['swingTrading']['stopLoss'],
                        period: item['swingTrading']['period'] ?? '',
                        expectedReturn:
                            (item['swingTrading']['expectedReturn'] ?? 0)
                                .toDouble(),
                      )
                    : null,
                longTerm: item['longTerm'] != null
                    ? TradingStrategy(
                        buyPrice: item['longTerm']['buyPrice'] ?? 0,
                        sellPrice: item['longTerm']['sellPrice'] ?? 0,
                        stopLoss: item['longTerm']['stopLoss'],
                        period: item['longTerm']['period'] ?? '',
                        expectedReturn:
                            (item['longTerm']['expectedReturn'] ?? 0)
                                .toDouble(),
                      )
                    : null,
              ))
          .toList();

      return (recommendations: recommendations, lastUpdated: lastUpdated);
    } catch (e) {
      debugPrint('❌ API 호출 중 예외 발생: $e');
      debugPrint('🔍 예외 타입: ${e.runtimeType}');
      debugPrint('📋 스택 트레이스: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _refreshRecommendations() async {
    await _loadRecommendations();
  }

  void _shareRecommendation(StockRecommendation rec) {
    final shareText = '''
🤖 AI 종목 추천: ${rec.stockName} (${rec.stockCode})

현재가: ₩${AiRecommendCard.formatPrice(rec.currentPrice)}
추천: ${rec.action}
목표가: ₩${AiRecommendCard.formatPrice(rec.targetPrice)}

추천 근거:
${rec.reasons.map((r) => '• $r').join('\n')}

StockWiki AI 추천
    ''';

    Clipboard.setData(ClipboardData(text: shareText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('추천 내용이 클립보드에 복사되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showEmpty =
        !_isLoading && _error == null && _recommendations.isEmpty;
    final showError = !_isLoading && _error != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        title: AiRecommendHeader(lastUpdated: _lastUpdated),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(showEmpty: showEmpty, showError: showError),
    );
  }

  Widget _buildBody({required bool showEmpty, required bool showError}) {
    if (_isLoading || showError || showEmpty) {
      return AiRecommendEmptyState(
        isLoading: _isLoading,
        error: _error,
        isEmpty: showEmpty,
        onRetry: _loadRecommendations,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRecommendations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          return AiRecommendCard(rec: _recommendations[index]);
        },
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class StockRecommendation {
  final String stockName;
  final String stockCode;
  final int currentPrice;
  final double changePercent;
  final int changeAmount;
  final int? previousClose;
  final String? priceSource;
  final String action;
  final List<String> reasons;
  final int targetPrice;
  final DateTime postedAt;
  final int likes;
  final int comments;
  final int shares;
  final TradingStrategy? dayTrading;
  final TradingStrategy? swingTrading;
  final TradingStrategy? longTerm;

  StockRecommendation({
    required this.stockName,
    required this.stockCode,
    required this.currentPrice,
    required this.changePercent,
    required this.changeAmount,
    this.previousClose,
    this.priceSource,
    required this.action,
    required this.reasons,
    required this.targetPrice,
    required this.postedAt,
    required this.likes,
    required this.comments,
    required this.shares,
    this.dayTrading,
    this.swingTrading,
    this.longTerm,
  });
}

class TradingStrategy {
  final int buyPrice;
  final int sellPrice;
  final int? stopLoss;
  final String period;
  final double expectedReturn;

  TradingStrategy({
    required this.buyPrice,
    required this.sellPrice,
    this.stopLoss,
    required this.period,
    required this.expectedReturn,
  });
}
