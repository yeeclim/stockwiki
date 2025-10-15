import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // 더미 데이터 완전 제거 - 실시간 API 데이터만 사용

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 실시간 API 데이터만 사용
      final recommendations = await _fetchFromAPI();
      
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      // API 실패 시 빈 목록 표시 (더미 데이터 사용 안함)
      print('❌ API 호출 실패: $e');
      setState(() {
        _recommendations = [];
        _isLoading = false;
        _error = '실시간 데이터를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  Future<List<StockRecommendation>> _fetchFromAPI() async {
    // 실제 API 호출 (새로고침 플래그 포함)
    final baseUrl = Uri.base.origin;
    final url = '$baseUrl/api/ai_recommend_list?limit=20&refresh=true';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['data'] as List<dynamic>;
      
      return results.map((item) => StockRecommendation(
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
    } else {
      throw Exception('API 호출 실패: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('🤖 AI 종목 추천', style: TextStyle(color: Colors.white)),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, color: Colors.blue, size: 48),
            const SizedBox(height: 16),
            const Text(
              '실시간 데이터를 불러오는 중입니다',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '실제 주가 데이터를 기반으로 한 AI 추천이 곧 표시됩니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
                          '실시간 데이터 없음',
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

