import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    // 1분마다 자동 갱신
    _startAutoRefresh();
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
    
    print('🌍 환경 정보: ${isLocalDev ? "로컬 개발" : "운영"}');
    print('🔗 현재 URL: $baseUrl');
    print('📱 User Agent: ${Uri.base.toString()}');
    
    if (isLocalDev) {
      print('🏠 로컬 개발 환경 감지 - API 호출 생략');
      setState(() {
        _isLoading = false;
        _error = null;
        _recommendations = [];
      });
      return;
    }

    try {
      print('🚀 운영 환경에서 API 호출 시작');
      // 실제 API 데이터만 사용
      final result = await _fetchFromAPI();
      
      print('✅ API 호출 성공: ${result.recommendations.length}개 추천 받음');
      setState(() {
        _recommendations = result.recommendations;
        _lastUpdated = result.lastUpdated;
        _isLoading = false;
      });
    } catch (e) {
      // API 실패 시 빈 목록 표시 (더미 데이터 사용 안함)
      print('❌ 운영 환경 API 호출 실패: $e');
      print('🔍 에러 타입: ${e.runtimeType}');
      print('📋 에러 상세: ${e.toString()}');
      
      if (!silent) {
        setState(() {
          _recommendations = [];
          _isLoading = false;
          _error = 'AI 추천 서비스를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }


  Future<int?> _getRealTimePrice(String symbol) async {
    try {
      // 네이버 증권에서 최신 주가 크롤링 시도
      final baseUrl = Uri.base.origin;
      final url = '$baseUrl/api/naver-stock?symbol=$symbol';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final price = data['data']['price'] as int?;
          print('📊 $symbol 최신 주가: ₩${price?.toString() ?? 'N/A'}');
          return price;
        }
      }
    } catch (e) {
      print('⚠️ $symbol 최신 주가 조회 실패: $e');
    }
    return null;
  }

  Future<({List<StockRecommendation> recommendations, DateTime? lastUpdated})> _fetchFromAPI() async {
    // 실제 API 호출 (새로고침 플래그 포함)
    final baseUrl = Uri.base.origin;
    final url = '$baseUrl/api/ai_recommend_list?limit=20&refresh=true';
    
    print('🌐 AI 추천 API 호출 URL: $url');
    print('📱 현재 도메인: $baseUrl');
    print('🕐 API 호출 시간: ${DateTime.now().toIso8601String()}');
    
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
          print('⏰ API 타임아웃 발생 (30초 초과)');
          throw Exception('API 응답 시간 초과 (30초)');
        },
      );
      
      print('📊 API 응답 상태: ${response.statusCode}');
      print('📄 API 응답 헤더: ${response.headers}');
      print('📄 응답 본문 길이: ${response.body.length}');
      print('📄 API 응답 본문 (첫 500자): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      
      // 응답 상태 코드별 처리
      if (response.statusCode != 200) {
        print('❌ HTTP 에러: ${response.statusCode} ${response.reasonPhrase}');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    
      // 응답이 JSON인지 확인
      final responseBody = response.body.trim();
      print('🔍 응답 본문 시작: ${responseBody.substring(0, responseBody.length > 50 ? 50 : responseBody.length)}');
      
      if (!responseBody.startsWith('{')) {
        print('❌ JSON 응답이 아님 - HTML 응답 감지');
        print('📄 전체 응답 본문: $responseBody');
        throw Exception('API가 JSON이 아닌 응답을 반환했습니다: ${responseBody.substring(0, 100)}...');
      }
      
      print('✅ JSON 응답 확인됨 - 파싱 시작');
      final data = json.decode(responseBody);
      print('📊 파싱된 JSON 데이터: ${data.runtimeType}');
      print('🔑 JSON 키들: ${data is Map ? (data as Map).keys.toList() : 'N/A'}');
      
      if (data is! Map) {
        throw Exception('JSON 응답이 객체가 아닙니다: ${data.runtimeType}');
      }
      
      if (data['success'] != true) {
        print('❌ API 응답에서 success=false');
        throw Exception('API 응답 실패: ${data['error'] ?? '알 수 없는 오류'}');
      }
      
      final results = data['data'] as List<dynamic>? ?? [];
      print('📋 추천 데이터 개수: ${results.length}');
      
      if (results.isEmpty) {
        print('⚠️ 추천 데이터가 비어있음');
      }
      
      // 마지막 업데이트 시간 파싱
      DateTime? lastUpdated;
      if (data['lastUpdated'] != null) {
        try {
          lastUpdated = DateTime.parse(data['lastUpdated']);
        } catch (e) {
          print('⚠️ lastUpdated 파싱 실패: $e');
        }
      }
      
      final recommendations = results.map((item) => StockRecommendation(
        stockName: item['stockName'] ?? '',
        stockCode: item['stockCode'] ?? '',
        currentPrice: item['currentPrice'] ?? 0, // null이면 0으로 처리
        changePercent: (item['changePercent'] ?? 0).toDouble(),
        changeAmount: item['changeAmount'] ?? 0,
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
      print('❌ API 호출 중 예외 발생: $e');
      print('🔍 예외 타입: ${e.runtimeType}');
      print('📋 스택 트레이스: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖 AI 종목 추천', style: TextStyle(color: Colors.white)),
            if (_lastUpdated != null)
              Text(
                '마지막 업데이트: ${_formatLastUpdated(_lastUpdated!)}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
    final isPositive = rec.changePercent >= 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (AI 프로필 + 시간)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.auto_graph, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'StockWiki AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(rec.postedAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionBadge(rec.action),
              ],
            ),
          ),

          // 종목 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 종목명
                Row(
                  children: [
                    const Text(
                      '🎯 ',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '${rec.stockName} (${rec.stockCode})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 가격 정보
                Row(
                  children: [
                    Text(
                      '현재가: ',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (rec.currentPrice > 0) ...[
                      Text(
                        '₩${_formatPrice(rec.currentPrice)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.red[900]?.withOpacity(0.3) : Colors.blue[900]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isPositive ? '▲' : '▼'} ${rec.changePercent.abs().toStringAsFixed(2)}% (${isPositive ? '+' : ''}${_formatPrice(rec.changeAmount)})',
                          style: TextStyle(
                            color: isPositive ? Colors.red[400] : Colors.blue[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[900]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '최신 데이터 없음',
                          style: TextStyle(
                            color: Colors.orange[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // 추천 근거
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 추천 근거',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // 투자 전략 (단타/스윙/중장기)
                const SizedBox(height: 12),
                _buildTradingStrategies(rec),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 인터랙션 버튼 (트위터 스타일)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInteractionButton(
                  icon: Icons.comment_outlined,
                  count: rec.comments,
                  color: Colors.grey[500]!,
                  onTap: () {},
                ),
                _buildInteractionButton(
                  icon: Icons.repeat,
                  count: rec.shares,
                  color: Colors.grey[500]!,
                  onTap: () {},
                ),
                _buildInteractionButton(
                  icon: Icons.favorite_border,
                  count: rec.likes,
                  color: Colors.grey[500]!,
                  activeColor: Colors.red,
                  onTap: () {},
                ),
                _buildInteractionButton(
                  icon: Icons.bookmark_border,
                  count: null,
                  color: Colors.grey[500]!,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingStrategies(StockRecommendation rec) {
    final strategies = <Widget>[];

    // 단타
    if (rec.dayTrading != null) {
      strategies.add(_buildStrategyCard(
        title: '🎯 단타',
        subtitle: rec.dayTrading!.period,
        strategy: rec.dayTrading!,
        color: Colors.orange,
      ));
    }

    // 스윙
    if (rec.swingTrading != null) {
      strategies.add(_buildStrategyCard(
        title: '📊 스윙',
        subtitle: rec.swingTrading!.period,
        strategy: rec.swingTrading!,
        color: Colors.blue,
      ));
    }

    // 중장기
    if (rec.longTerm != null) {
      strategies.add(_buildStrategyCard(
        title: '📈 중장기',
        subtitle: rec.longTerm!.period,
        strategy: rec.longTerm!,
        color: Colors.green,
      ));
    }

    if (strategies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💼 투자 전략',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
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
    required TradingStrategy strategy,
    required Color color,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${strategy.expectedReturn.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
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
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              Text(
                '₩${_formatPrice(strategy.buyPrice)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              Text(
                '₩${_formatPrice(strategy.sellPrice)}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          // 손절가
          if (strategy.stopLoss != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '손절',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                Text(
                  '₩${_formatPrice(strategy.stopLoss!)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bgColor;
    Color textColor;
    
    switch (action) {
      case '매수':
        bgColor = Colors.red[900]!.withOpacity(0.3);
        textColor = Colors.red[400]!;
        break;
      case '매도':
        bgColor = Colors.blue[900]!.withOpacity(0.3);
        textColor = Colors.blue[400]!;
        break;
      case '보유':
        bgColor = Colors.grey[800]!;
        textColor = Colors.grey[400]!;
        break;
      default:
        bgColor = Colors.grey[800]!;
        textColor = Colors.grey[400]!;
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
}

// 데이터 모델
class StockRecommendation {
  final String stockName;
  final String stockCode;
  final int currentPrice;
  final double changePercent;
  final int changeAmount;
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

