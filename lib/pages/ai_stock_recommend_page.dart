import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/bookmark_service.dart';

class AiStockRecommendPage extends StatefulWidget {
  const AiStockRecommendPage({super.key});

  @override
  State<AiStockRecommendPage> createState() => _AiStockRecommendPageState();
}

class _AiStockRecommendPageState extends State<AiStockRecommendPage> {
  // 실제 API에서 가져온 추천 데이터
  List<StockRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefreshTimer;
  // 좋아요 및 북마크 상태 관리
  final Set<String> _likedStocks = {};
  final Set<String> _bookmarkedStocks = {};

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadBookmarks();
    // 1분마다 자동 갱신
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

    // 환경 구분 및 로깅
    final baseUrl = Uri.base.origin;
    final isLocalDev = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    
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
      // 실제 API 데이터만 사용
      final result = await _fetchFromAPI();
      
      debugPrint('✅ API 호출 성공: ${result.recommendations.length}개 추천 받음');
      setState(() {
        _recommendations = result.recommendations;
        _lastUpdated = result.lastUpdated;
        _isLoading = false;
      });
    } catch (e) {
      // API 실패 시 빈 목록 표시 (더미 데이터 사용 안함)
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

  Future<({List<StockRecommendation> recommendations, DateTime? lastUpdated})> _fetchFromAPI() async {
    // 실제 API 호출 (새로고침 플래그 포함)
    final baseUrl = Uri.base.origin;
    final url = '$baseUrl/api/ai_recommend_list?limit=20&refresh=true';
    
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
      debugPrint('📄 API 응답 본문 (첫 500자): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      
      // 응답 상태 코드별 처리
      if (response.statusCode != 200) {
        debugPrint('❌ HTTP 에러: ${response.statusCode} ${response.reasonPhrase}');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    
      // 응답이 JSON인지 확인
      final responseBody = response.body.trim();
      debugPrint('🔍 응답 본문 시작: ${responseBody.substring(0, responseBody.length > 50 ? 50 : responseBody.length)}');
      
      if (!responseBody.startsWith('{')) {
        debugPrint('❌ JSON 응답이 아님 - HTML 응답 감지');
        debugPrint('📄 전체 응답 본문: $responseBody');
        throw Exception('API가 JSON이 아닌 응답을 반환했습니다: ${responseBody.substring(0, 100)}...');
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
      
      // 마지막 업데이트 시간 파싱
      DateTime? lastUpdated;
      if (data['lastUpdated'] != null) {
        try {
          lastUpdated = DateTime.parse(data['lastUpdated']);
        } catch (e) {
          debugPrint('⚠️ lastUpdated 파싱 실패: $e');
        }
      }
      
      final recommendations = results.map((item) => StockRecommendation(
        stockName: item['stockName'] ?? '',
        stockCode: item['stockCode'] ?? '',
        currentPrice: item['currentPrice'] ?? 0, // null이면 0으로 처리
        changePercent: (item['changePercent'] ?? 0).toDouble(),
        changeAmount: item['changeAmount'] ?? 0,
        previousClose: item['previousClose'], // 전일 종가 추가
        priceSource: item['priceSource'], // 가격 출처 추가 (real-time, fallback 등)
        action: item['action'] ?? '보유',
        reasons: List<String>.from(item['reasons'] ?? []),
        targetPrice: item['targetPrice'] ?? 0,
        postedAt: DateTime.parse(item['postedAt'] ?? DateTime.now().toIso8601String()),
        likes: item['likes'] ?? 0,
        comments: item['comments'] ?? 0,
        shares: item['shares'] ?? 0,
        dayTrading: item['dayTrading'] != null
            ? TradingStrategy(
                buyPrice: item['dayTrading']['buyPrice'] ?? 0,
                sellPrice: item['dayTrading']['sellPrice'] ?? 0,
                stopLoss: item['dayTrading']['stopLoss'],
                period: item['dayTrading']['period'] ?? '',
                expectedReturn: (item['dayTrading']['expectedReturn'] ?? 0).toDouble(),
              )
            : null,
        swingTrading: item['swingTrading'] != null
            ? TradingStrategy(
                buyPrice: item['swingTrading']['buyPrice'] ?? 0,
                sellPrice: item['swingTrading']['sellPrice'] ?? 0,
                stopLoss: item['swingTrading']['stopLoss'],
                period: item['swingTrading']['period'] ?? '',
                expectedReturn: (item['swingTrading']['expectedReturn'] ?? 0).toDouble(),
              )
            : null,
        longTerm: item['longTerm'] != null
            ? TradingStrategy(
                buyPrice: item['longTerm']['buyPrice'] ?? 0,
                sellPrice: item['longTerm']['sellPrice'] ?? 0,
                stopLoss: item['longTerm']['stopLoss'],
                period: item['longTerm']['period'] ?? '',
                expectedReturn: (item['longTerm']['expectedReturn'] ?? 0).toDouble(),
              )
            : null,
      )).toList();
      
      return (recommendations: recommendations, lastUpdated: lastUpdated);
      
    } catch (e) {
      debugPrint('❌ API 호출 중 예외 발생: $e');
      debugPrint('🔍 예외 타입: ${e.runtimeType}');
      debugPrint('📋 스택 트레이스: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 AI 종목 추천',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (_lastUpdated != null)
              Text(
                '마지막 업데이트: ${_formatLastUpdated(_lastUpdated!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      final baseUrl = Uri.base.origin;
      final isLocalDev = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocalDev ? Icons.cloud_off : Icons.refresh,
              color: isLocalDev ? Colors.orange : Colors.blue,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isLocalDev 
                ? 'AI 추천 서비스는 운영서버에서만 지원됩니다'
                : '최신 데이터를 불러오는 중입니다',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isLocalDev
                ? '실제 서비스에서는 최신 주가 데이터를 기반으로 한\nAI 종목 추천을 제공합니다'
                : '최신 주가 데이터를 기반으로 한 AI 추천이 곧 표시됩니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!isLocalDev)
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('새로고침'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRecommendations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          return _buildRecommendationCard(_recommendations[index]);
        },
      ),
    );
  }

  Future<void> _refreshRecommendations() async {
    await _loadRecommendations();
  }

  Widget _buildRecommendationCard(StockRecommendation rec) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine card color and border based on recommendation action
    Color actionColor;
    switch (rec.action) {
      case '강력매수':
      case '매수':
        actionColor = Colors.red;
        break;
      case '매도':
      case '강력매도':
        actionColor = Colors.blue;
        break;
      default:
        actionColor = Colors.grey;
    }

    return Card(
      elevation: theme.cardTheme.elevation,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (AI 프로필 + 시간)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.auto_graph, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'StockWiki AI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(rec.postedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionBadge(rec.action),
                ],
              ),
            ),

            Divider(height: 1, color: theme.dividerColor),

            // 종목 정보
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 종목명과 현재가
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              rec.stockName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rec.stockCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      /* 현재가 표시 (옵션)
                      if (rec.currentPrice > 0)
                        Text(
                          '₩${_formatPrice(rec.currentPrice)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: rec.changePercent >= 0 ? Colors.red : Colors.blue,
                          ),
                        ),
                      */
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 기간별 목표가 표시 (단타/스윙/중장기)
                  _buildTargetPrices(rec),
                  const SizedBox(height: 16),

                  // 추천 근거
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, 
                              size: 16, 
                              color: theme.colorScheme.primary
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '추천 근거',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...rec.reasons.map((reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                  // 투자 전략 (단타/스윙/중장기) - 가격 정보 있을 때만 표시
                  if (rec.currentPrice > 0) ...[
                    const SizedBox(height: 12),
                    _buildTradingStrategies(rec, rec.currentPrice),
                  ],
                ],
              ),
            ),
            
            // 인터랙션 버튼 제거됨 (사용자 요청)
          ],
        ),
      ),
    );
  }

  // 기간별 목표가 표시
  Widget _buildTargetPrices(StockRecommendation rec) {
    final theme = Theme.of(context);
    // 기준 가격 계산 (현재가 > 전일 종가 > 참고 가격)
    int basePrice = 0;
    String priceLabel = '';
    
    // 가격 정보가 없으면 아예 표시하지 않음 (사용자 요청)
    if (rec.currentPrice <= 0) {
      return const SizedBox.shrink();
    }

    if (rec.currentPrice > 0 && rec.priceSource == 'real-time') {
      basePrice = rec.currentPrice;
      priceLabel = '현재가 기준';
    } else if (rec.previousClose != null && rec.previousClose! > 0) {
      basePrice = rec.previousClose!;
      priceLabel = '전일 종가 기준';
    } else {
       // 가격 정보가 없으면 아예 표시하지 않음
       return const SizedBox.shrink();
    }

    // 기간별 목표가 계산
    final dayTarget = (basePrice * 1.03).round(); // 단타: +3%
    final swingTarget = (basePrice * 1.08).round(); // 스윙: +8%
    final longTarget = (basePrice * 1.20).round(); // 중장기: +20%

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '🎯 기간별 목표가',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (priceLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priceLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTargetPriceCard(
                title: '단타',
                period: '1~3일',
                targetPrice: dayTarget,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTargetPriceCard(
                title: '스윙',
                period: '1주~1개월',
                targetPrice: swingTarget,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTargetPriceCard(
                title: '중장기',
                period: '3개월~1년',
                targetPrice: longTarget,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetPriceCard({
    required String title,
    required String period,
    required int targetPrice,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            period,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₩${_formatPrice(targetPrice)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingStrategies(StockRecommendation rec, int basePrice) {
    final theme = Theme.of(context);
    final strategies = <Widget>[];

    // 기준 가격(현재가 또는 전일 종가)이 0이면 계산하지 않음
    if (basePrice <= 0) {
      return const SizedBox.shrink();
    }

    // 단타 전략 (기준 가격으로 동적 계산)
    strategies.add(_buildStrategyCard(
      title: '🎯 단타',
      subtitle: '1~3일',
      currentPrice: basePrice,
      buyPricePercent: 99.5,
      sellPricePercent: 103.0,
      stopLossPercent: 98.0,
      expectedReturn: 3.0,
      color: Colors.orange,
    ));

    // 스윙 전략
    strategies.add(_buildStrategyCard(
      title: '📊 스윙',
      subtitle: '1주~1개월',
      currentPrice: basePrice,
      buyPricePercent: 98.5,
      sellPricePercent: 108.0,
      stopLossPercent: 96.0,
      expectedReturn: 8.5,
      color: Colors.blue,
    ));

    // 중장기 전략
    strategies.add(_buildStrategyCard(
      title: '📈 중장기',
      subtitle: '3개월~1년',
      currentPrice: basePrice,
      buyPricePercent: 100.0,
      sellPricePercent: 120.0,
      stopLossPercent: 93.0,
      expectedReturn: 20.0,
      color: Colors.green,
    ));

    if (strategies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💼 투자 전략',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: strategies.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: s,
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String title,
    required String subtitle,
    required int currentPrice,
    required double buyPricePercent,
    required double sellPricePercent,
    required double stopLossPercent,
    required double expectedReturn,
    required Color color,
  }) {
    final theme = Theme.of(context);
    // 현재가 기준으로 동적 계산
    final buyPrice = (currentPrice * buyPricePercent / 100).round();
    final sellPrice = (currentPrice * sellPricePercent / 100).round();
    final stopLoss = (currentPrice * stopLossPercent / 100).round();
    
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${expectedReturn.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          
          // 매수가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '매수',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₩${_formatPrice(buyPrice)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // 매도가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '매도',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₩${_formatPrice(sellPrice)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          // 손절가
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '손절',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₩${_formatPrice(stopLoss)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bgColor;
    Color textColor;
    final theme = Theme.of(context);
    
    switch (action) {
      case '매수':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case '매도':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      case '보유':
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
      default:
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        action,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required int? count,
    required Color color,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _shareRecommendation(StockRecommendation rec) {
    final shareText = '''
🤖 AI 종목 추천: ${rec.stockName} (${rec.stockCode})

현재가: ₩${_formatPrice(rec.currentPrice)}
추천: ${rec.action}
목표가: ₩${_formatPrice(rec.targetPrice)}

추천 근거:
${rec.reasons.map((r) => '• $r').join('\n')}

StockWiki AI 추천
    ''';

    // 클립보드에 복사
    Clipboard.setData(ClipboardData(text: shareText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('추천 내용이 클립보드에 복사되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// 데이터 모델
class StockRecommendation {
  final String stockName;
  final String stockCode;
  final int currentPrice;
  final double changePercent;
  final int changeAmount;
  final int? previousClose; // 전일 종가 추가
  final String? priceSource; // 가격 출처 (real-time, fallback 등)
  final String action; // 매수, 매도, 보유
  final List<String> reasons;
  final int targetPrice;
  final DateTime postedAt;
  final int likes;
  final int comments;
  final int shares;
  final TradingStrategy? dayTrading; // 단타 (1-3일)
  final TradingStrategy? swingTrading; // 스윙 (1주일~1개월)
  final TradingStrategy? longTerm; // 중장기 (3개월~1년)

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

// 투자 전략 모델
class TradingStrategy {
  final int buyPrice; // 매수단가
  final int sellPrice; // 매도단가
  final int? stopLoss; // 손절가 (선택)
  final String period; // 기간 표시용
  final double expectedReturn; // 기대 수익률

  TradingStrategy({
    required this.buyPrice,
    required this.sellPrice,
    this.stopLoss,
    required this.period,
    required this.expectedReturn,
  });
}

