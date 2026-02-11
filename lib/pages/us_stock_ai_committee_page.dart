import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'us_stock_detail_page.dart';
import '../models/committee_recommendation.dart';

class UsStockAiCommitteePage extends StatefulWidget {
  const UsStockAiCommitteePage({super.key});

  @override
  State<UsStockAiCommitteePage> createState() => _UsStockAiCommitteePageState();
}

class _UsStockAiCommitteePageState extends State<UsStockAiCommitteePage> {
  final TextEditingController _searchController = TextEditingController();
  List<CommitteeRecommendation> _recommendations = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  DateTime? _lastUpdated;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 초기 로딩 제거: 사용자가 검색하기 전까지는 아무것도 로드하지 않음
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStock(String query) async {
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색어를 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _error = null;
      _searchQuery = query.trim();
      _recommendations = [];
    });

    try {
      List<Stock> stocks = [];
      
      // 미국 주식인지 국내 주식인지 판단 (영문/숫자 조합은 미국 주식으로 가정)
      final isUSStock = RegExp(r'^[A-Za-z0-9]+$').hasMatch(query);
      
      debugPrint('🔍 주식 검색 시작: $query (${isUSStock ? "미국" : "국내"} 주식)');
      
      if (isUSStock) {
        // 미국 주식 검색
        debugPrint('🇺🇸 미국 주식 검색 중...');
        stocks = await FMPService.fetchStocks(query);
        debugPrint('✅ 미국 주식 검색 결과: ${stocks.length}개');
        if (stocks.isNotEmpty) {
          debugPrint('📊 첫 번째 결과: ${stocks[0].name} (${stocks[0].symbol}), 가격: ${stocks[0].price}, 변동률: ${stocks[0].changePercent}');
        }
      } else {
        // 국내 주식 검색
        debugPrint('🇰🇷 국내 주식 검색 중...');
        stocks = await _searchKoreanStock(query);
        debugPrint('✅ 국내 주식 검색 결과: ${stocks.length}개');
        if (stocks.isNotEmpty) {
          debugPrint('📊 첫 번째 결과: ${stocks[0].name} (${stocks[0].symbol}), 가격: ${stocks[0].price}, 변동률: ${stocks[0].changePercent}');
        }
      }

      if (stocks.isEmpty) {
        debugPrint('⚠️ 검색 결과가 없습니다.');
        setState(() {
          _error = '검색 결과가 없습니다. 다른 키워드로 검색해주세요.';
          _isLoading = false;
          _isSearching = false;
        });
        return;
      }

      // 첫 번째 검색 결과에 대해 AI 검증위원회에 질문
      final stock = stocks[0];
      debugPrint('🤖 AI 검증위원회에 질문 전송 중...');
      final committeeResult = await _askAiCommittee(stock);
      debugPrint('✅ AI 검증위원회 응답 수신 완료');

      setState(() {
        _recommendations = [committeeResult];
        _lastUpdated = DateTime.now();
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('💥 검색 중 오류 발생: $e');
      debugPrint('📚 오류 타입: ${e.runtimeType}');
      setState(() {
        _error = '검색 중 오류가 발생했습니다: $e';
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  // 국내 주식 검색
  Future<List<Stock>> _searchKoreanStock(String keyword) async {
    // 로컬 개발 환경 감지 및 API URL 설정
    final baseUrl = Uri.base.origin;
    final isLocalDev = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    
    // 로컬 개발 환경에서는 별도 API 서버 사용 (Vercel dev 서버)
    // 운영 환경에서는 같은 도메인의 API 사용
    final apiBaseUrl = isLocalDev 
        ? 'http://localhost:3000'  // Vercel dev 서버 포트
        : baseUrl;
    
    // URL 인코딩 처리
    final encodedKeyword = Uri.encodeComponent(keyword);
    final url = '$apiBaseUrl/api/stock-search-full?keyword=$encodedKeyword&limit=1';
    
    debugPrint('🔍 국내 주식 검색 환경: ${isLocalDev ? "로컬 개발" : "운영"}');
    debugPrint('🔍 국내 주식 검색 URL: $url');
    
    try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 10),
        );

        debugPrint('📊 국내 주식 검색 응답 상태: ${response.statusCode}');
        debugPrint('📄 국내 주식 검색 응답 Content-Type: ${response.headers['content-type']}');
        
        // 응답이 HTML인지 확인
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
          debugPrint('❌ 국내 주식 검색 실패: API가 HTML을 반환했습니다 (404 또는 서버 오류)');
          debugPrint('💡 Vercel dev 서버가 실행 중인지 확인하세요: vercel dev');
          debugPrint('📄 응답 본문 (처음 200자): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          return [];
        }

        if (response.statusCode == 200) {
          try {
            final data = json.decode(response.body);
            debugPrint('📋 국내 주식 검색 데이터: $data');
            
            if (data['success'] == true && data['data'] != null) {
              final stocks = (data['data'] as List)
                  .map((item) => Stock.fromKrxData(item))
                  .toList();
              debugPrint('✅ 국내 주식 검색 성공: ${stocks.length}개');
              return stocks;
            } else {
              debugPrint('⚠️ 국내 주식 검색 실패: success=${data['success']}, error=${data['error']}');
            }
          } catch (e) {
            debugPrint('❌ JSON 파싱 오류: $e');
            debugPrint('📄 응답 본문 (처음 500자): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
            return [];
          }
        } else {
          debugPrint('❌ 국내 주식 검색 실패: HTTP ${response.statusCode}');
          debugPrint('📄 응답 본문 (처음 200자): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        }
        return [];
      } on http.ClientException catch (e) {
        debugPrint('❌ 네트워크 오류 (API 서버에 연결할 수 없음): $e');
        debugPrint('💡 Vercel dev 서버가 실행 중인지 확인하세요:');
        debugPrint('   1. 터미널에서 "vercel dev" 또는 "npm run dev" 실행');
        debugPrint('   2. API 서버가 http://localhost:3000 에서 실행 중인지 확인');
        return [];
      } catch (e) {
        debugPrint('💥 국내 주식 검색 오류: $e');
        debugPrint('📚 오류 타입: ${e.runtimeType}');
        if (e.toString().contains('XMLHttpRequest') || e.toString().contains('CORS')) {
          debugPrint('💡 CORS 오류일 수 있습니다. API 서버의 CORS 설정을 확인하세요.');
        }
        return [];
      }
  }

  Future<CommitteeRecommendation> _askAiCommittee(Stock stock) async {
    try {
      // 로컬 개발 환경 감지 및 API URL 설정
      final baseUrl = Uri.base.origin;
      final isLocalDev = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
      
      // 로컬 개발 환경에서는 별도 API 서버 사용 (Vercel dev 서버)
      // 운영 환경에서는 같은 도메인의 API 사용
      final apiBaseUrl = isLocalDev 
          ? 'http://localhost:3000'  // Vercel dev 서버 포트
          : baseUrl;
      
      final url = '$apiBaseUrl/api/ai-committee-verify';
      
      debugPrint('🔍 AI 검증위원회 환경: ${isLocalDev ? "로컬 개발" : "운영"}');
      
      // 가격 포맷 (국내 주식은 원화, 미국 주식은 달러)
      final isKorean = RegExp(r'^\d+ ?\d* ?$').hasMatch(stock.symbol) || RegExp(r'^\d+$').hasMatch(stock.symbol);
      final priceFormat = isKorean 
          ? '₩${stock.price?.toStringAsFixed(0) ?? 'N/A'}'
          : '\$${stock.price?.toStringAsFixed(2) ?? 'N/A'}';
      
      // 더 상세한 질문 구성
      final changeInfo = stock.changePercent != null 
          ? '현재 ${stock.changePercent! >= 0 ? '상승' : '하락'}률: ${(stock.changePercent!).abs().toStringAsFixed(2)}%'
          : '가격 변동 정보 없음';
      
      final question = '${stock.name} (${stock.symbol}) 주식에 대한 투자 의견을 분석해주세요.\n\n'
          '현재 가격: $priceFormat\n'
          '$changeInfo\n\n'
          '다음 관점에서 종합적으로 분석해주세요:\n' +
          '1. 재무 건전성 및 수익성\n' +
          '2. 성장 가능성 및 시장 전망\n' +
          '3. 기술적 분석 (가격 추세, 거래량 등)\n' +
          '4. 리스크 요인\n' +
          '5. 투자 가치 평가\n\n' +
          '위 분석을 바탕으로 투자 의견을 제시해주세요.';
      
      debugPrint('🎯 AI 검증위원회 질문: $question');
      debugPrint('📊 주식 정보: ${stock.name} (${stock.symbol}), 가격: ${stock.price}, 변동률: ${stock.changePercent}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'question': question,
          'symbol': stock.symbol,
          'price': stock.price,
          'changePercent': stock.changePercent,
          'isKorean': isKorean,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('📊 AI 검증위원회 응답 상태: ${response.statusCode}');
      debugPrint('📄 AI 검증위원회 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📋 AI 검증위원회 데이터: $data');
        
        // success 필드 확인
        if (data['success'] == false) {
          throw Exception('API 응답 실패: ${data['error'] ?? '알 수 없는 오류'}');
        }
        
        return CommitteeRecommendation(
          stock: stock,
          models: List<AiModelResponse>.from(
            (data['models'] as List? ?? []).map((m) => AiModelResponse.fromJson(m))
          ),
          verificationScore: (data['verificationScore'] ?? 0).toDouble(),
          agreement: data['agreement'] ?? '분산',
          finalRecommendation: data['finalRecommendation'] ?? 'Watch',
          summary: data['summary'] ?? '',
        );
      } else {
        final errorBody = response.body;
        debugPrint('❌ AI 검증위원회 API 호출 실패: HTTP ${response.statusCode}, 응답: $errorBody');
        throw Exception('API 호출 실패: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('💥 AI 검증위원회 오류: $e');
      debugPrint('📚 오류 타입: ${e.runtimeType}');
      
      // 에러 시 기본 응답 반환
      return CommitteeRecommendation(
        stock: stock,
        models: [],
        verificationScore: 0,
        agreement: '오류',
        finalRecommendation: 'Watch',
        summary: 'AI 검증 중 오류가 발생했습니다: ${e.toString()}',
      );
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
      return '${difference.inDays}일 전';
    }
  }

  String _formatPrice(Stock stock) {
    if (stock.price == null) return 'N/A';
    
    // 국내 주식인지 판단 (숫자로만 구성된 심볼은 국내 주식)
    final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol);
    
    if (isKorean) {
      // 원화 표시
      final price = stock.price!.toInt();
      return '₩${price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
    } else {
      // 달러 표시
      return '\$${stock.price!.toStringAsFixed(2)}';
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 AI 검증위원회',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _searchQuery.isNotEmpty && !_isLoading
                ? () => _searchStock(_searchQuery)
                : null,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 검색창
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '주식 검색 (예: AAPL, 삼성전자, 005930)',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (value) => _searchStock(value),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _searchStock(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(100, 56),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '검증',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '💡 미국주식(예: AAPL) 또는 국내주식(예: 삼성전자, 005930)을 검색하세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // 결과 영역
        Expanded(
          child: _buildResults(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'AI 검증위원회가 분석 중입니다...',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'ChatGPT, Gemini, Ollama 모델이 동시에 검증하고 있습니다',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchQuery.isNotEmpty && !_isLoading
                  ? () => _searchStock(_searchQuery)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (!_isSearching && _recommendations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, color: Colors.green[400], size: 64),
              const SizedBox(height: 16),
              Text(
                'AI 검증위원회',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '위 검색창에 주식을 입력하고\nAI 검증위원회의 검증을 받아보세요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔍 검증 프로세스',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.green[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProcessStep('1', '주식 검색', '미국주식 또는 국내주식 검색'),
                    _buildProcessStep('2', 'AI 분석', 'ChatGPT, Gemini, Ollama가 동시 분석'),
                    _buildProcessStep('3', '결과 검증', '여러 AI의 의견을 비교하여 검증도 계산'),
                    _buildProcessStep('4', '리포팅', '종합 분석 결과를 리포트로 제공'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 검색 결과가 있으면 검색 결과만 표시, 없으면 추천 종목 표시
    if (_isSearching && _recommendations.isNotEmpty) {
      // 검색 결과 표시
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final rec = _recommendations[index];
          return _buildRecommendationCard(rec);
        },
      );
    } else if (!_isSearching && _recommendations.isNotEmpty) {
      // 추천 종목 표시 (현재는 사용되지 않음)
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 추천 종목 헤더
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '추천 종목',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recommendations = [];
                    });
                  },
                  child: Text(
                    '숨기기',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          // 추천 종목 카드들
          ..._recommendations.map((rec) => _buildRecommendationCard(rec)),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildProcessStep(String number, String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(CommitteeRecommendation rec) {
    final theme = Theme.of(context);
    final stock = rec.stock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: theme.cardTheme.elevation,
        color: theme.cardTheme.color,
        shape: theme.cardTheme.shape,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsStockDetailPage(stock: stock),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stock.symbol,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 검증도 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getVerificationColor(rec.verificationScore)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getVerificationColor(rec.verificationScore),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '검증도 ${rec.verificationScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _getVerificationColor(rec.verificationScore),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rec.finalRecommendation,
                            style: TextStyle(
                              color: _getRecommendationColor(rec.finalRecommendation),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 가격 정보
                Row(
                  children: [
                    Text(
                      _formatPrice(stock),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (stock.changePercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (stock.changePercent! >= 0 ? Colors.green : Colors.red)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: stock.changePercent! >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 16),
                
                // AI 분석 요약
                Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI 분석 요약',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rec.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 모델별 의견 (간략히)
                Row(
                  children: rec.models.take(3).map((model) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: '${model.modelName}: ${model.reasoning}',
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: _getRecommendationColor(model.recommendation).withOpacity(0.2),
                          child: Text(
                            model.modelName[0],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getRecommendationColor(model.recommendation),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getVerificationColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.blue;
    return Colors.orange;
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation.toLowerCase()) {
      case 'buy':
      case 'strong buy':
      case '매수':
      case '강력 매수':
        return Colors.green;
      case 'sell':
      case 'strong sell':
      case '매도':
      case '강력 매도':
        return Colors.red;
      case 'hold':
      case '보유':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
