import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/news.dart';
import '../services/news_service.dart';
import '../services/us_stock_news_service.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'us_stock_detail_page.dart';
import '../models/committee_recommendation.dart';
import '../utils/number_format_utils.dart';

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
  List<News> _stockNews = [];
  bool _isLoadingNews = false;

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

  Future<void> _loadNewsForStock(Stock stock) async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);
    try {
      final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol) ||
          stock.symbol.endsWith('.KS') ||
          stock.symbol.endsWith('.KQ') ||
          RegExp(r'[가-힣]').hasMatch(stock.name);
      final List<News> news;
      if (isKorean) {
        news = await NewsService.searchStockNews(stock.name,
            isKoreanStock: true, symbol: stock.symbol);
      } else {
        news = await UsStockNewsService.fetchStockNews(stock.symbol,
            stockName: stock.name);
      }
      if (mounted) {
        setState(() {
          _stockNews = news;
          _isLoadingNews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingNews = false);
    }
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

      // 한글 포함 또는 순수 숫자(종목코드)이면 국내 주식으로 바로 판단
      final isDefinitelyKorean =
          RegExp(r'[가-힣]').hasMatch(query) || RegExp(r'^\d+$').hasMatch(query);

      if (isDefinitelyKorean) {
        stocks = await _searchKoreanStock(query);
      } else {
        // 영문/혼합: 서버사이드 미국 주식 검색 → 없으면 국내 영문명 검색
        stocks = await _searchUsStock(query);
        if (stocks.isEmpty) {
          stocks = await _searchKoreanStock(query);
        }
      }

      if (stocks.isEmpty) {
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
        _stockNews = [];
      });
      _loadNewsForStock(stock);
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

  // 미국 주식 검색 (서버사이드 Yahoo Finance)
  Future<List<Stock>> _searchUsStock(String keyword) async {
    final baseUrl = Uri.base.origin;
    final isLocalDev =
        baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    final apiBaseUrl = isLocalDev ? 'http://localhost:3000' : baseUrl;
    final url =
        '$apiBaseUrl/api/us-stock-search?keyword=${Uri.encodeComponent(keyword)}';

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => Stock(
                    symbol: item['symbol'] ?? '',
                    name: item['name'] ?? '',
                    price: (item['price'] as num?)?.toDouble(),
                    change: (item['change'] as num?)?.toDouble(),
                    changePercent: (item['changePercent'] as num?)?.toDouble(),
                    volume: (item['volume'] as num?)?.toInt(),
                    marketCap: (item['marketCap'] as num?)?.toInt(),
                  ))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('미국 주식 검색 오류: $e');
    }
    return [];
  }

  // 국내 주식 검색
  Future<List<Stock>> _searchKoreanStock(String keyword) async {
    // 로컬 개발 환경 감지 및 API URL 설정
    final baseUrl = Uri.base.origin;
    final isLocalDev =
        baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

    // 로컬 개발 환경에서는 별도 API 서버 사용 (Vercel dev 서버)
    // 운영 환경에서는 같은 도메인의 API 사용
    final apiBaseUrl = isLocalDev
        ? 'http://localhost:3000' // Vercel dev 서버 포트
        : baseUrl;

    // URL 인코딩 처리
    final encodedKeyword = Uri.encodeComponent(keyword);
    final url =
        '$apiBaseUrl/api/stock-search-full?keyword=$encodedKeyword&limit=1';

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
      debugPrint(
          '📄 국내 주식 검색 응답 Content-Type: ${response.headers['content-type']}');

      // 응답이 HTML인지 확인
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') ||
          response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('❌ 국내 주식 검색 실패: API가 HTML을 반환했습니다 (404 또는 서버 오류)');
        debugPrint('💡 Vercel dev 서버가 실행 중인지 확인하세요: vercel dev');
        debugPrint(
            '📄 응답 본문 (처음 200자): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
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
            debugPrint(
                '⚠️ 국내 주식 검색 실패: success=${data['success']}, error=${data['error']}');
          }
        } catch (e) {
          debugPrint('❌ JSON 파싱 오류: $e');
          debugPrint(
              '📄 응답 본문 (처음 500자): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
          return [];
        }
      } else {
        debugPrint('❌ 국내 주식 검색 실패: HTTP ${response.statusCode}');
        debugPrint(
            '📄 응답 본문 (처음 200자): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
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
      if (e.toString().contains('XMLHttpRequest') ||
          e.toString().contains('CORS')) {
        debugPrint('💡 CORS 오류일 수 있습니다. API 서버의 CORS 설정을 확인하세요.');
      }
      return [];
    }
  }

  Future<CommitteeRecommendation> _askAiCommittee(Stock stock) async {
    try {
      // 로컬 개발 환경 감지 및 API URL 설정
      final baseUrl = Uri.base.origin;
      final isLocalDev =
          baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

      // 로컬 개발 환경에서는 별도 API 서버 사용 (Vercel dev 서버)
      // 운영 환경에서는 같은 도메인의 API 사용
      final apiBaseUrl = isLocalDev
          ? 'http://localhost:3000' // Vercel dev 서버 포트
          : baseUrl;

      final url = '$apiBaseUrl/api/ai-committee-verify';

      debugPrint('🔍 AI 검증위원회 환경: ${isLocalDev ? "로컬 개발" : "운영"}');

      // 가격 포맷 (국내 주식은 원화, 미국 주식은 달러)
      final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol) ||
          stock.symbol.endsWith('.KS') ||
          stock.symbol.endsWith('.KQ') ||
          RegExp(r'[가-힣]').hasMatch(stock.name);

      final priceFormat = isKorean
          ? '₩${stock.price?.toStringAsFixed(0) ?? 'N/A'}'
          : '\$${stock.price?.toStringAsFixed(2) ?? 'N/A'}';

      // 더 상세한 질문 구성
      final changeInfo = stock.changePercent != null
          ? '현재 ${stock.changePercent! >= 0 ? '상승' : '하락'}률: ${(stock.changePercent!).abs().toStringAsFixed(2)}%'
          : '가격 변동 정보 없음';

      final question =
          '${stock.name} (${stock.symbol}) 주식에 대한 투자 의견을 분석해주세요.\n\n'
          '현재 가격: $priceFormat\n'
          '$changeInfo\n\n'
          '다음 관점에서 종합적으로 분석해주세요:\n'
          '1. 재무 건전성 및 수익성\n'
          '2. 성장 가능성 및 시장 전망\n'
          '3. 기술적 분석 (가격 추세, 거래량 등)\n'
          '4. 리스크 요인\n'
          '5. 투자 가치 평가\n\n'
          '위 분석을 바탕으로 투자 의견을 제시해주세요.';

      debugPrint('🎯 AI 검증위원회 질문: $question');
      debugPrint(
          '📊 주식 정보: ${stock.name} (${stock.symbol}), 가격: ${stock.price}, 변동률: ${stock.changePercent}');

      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 60));

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
          models: List<AiModelResponse>.from((data['models'] as List? ?? [])
              .map((m) => AiModelResponse.fromJson(m))),
          verificationScore: (data['verificationScore'] ?? 0).toDouble(),
          agreement: data['agreement'] ?? '분산',
          finalRecommendation: data['finalRecommendation'] ?? 'Watch',
          summary: data['summary'] ?? '',
        );
      } else {
        final errorBody = response.body;
        debugPrint(
            '❌ AI 검증위원회 API 호출 실패: HTTP ${response.statusCode}, 응답: $errorBody');
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

    // 국내 주식인지 판단
    final isKorean = RegExp(r'^\d+$').hasMatch(stock.symbol) ||
        stock.symbol.endsWith('.KS') ||
        stock.symbol.endsWith('.KQ') ||
        RegExp(r'[가-힣]').hasMatch(stock.name);

    if (isKorean) {
      // 원화 표시
      return '₩${formatWithCommas(stock.price!)}';
    } else {
      // 달러 표시
      return '\$${formatWithCommas(stock.price!, decimals: 2)}';
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
                        hintText: '주식 검색 (예: AAPL, 삼성전자, LS ELECTRIC, 005930)',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: theme.colorScheme.onSurfaceVariant),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: theme.colorScheme.onSurfaceVariant),
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
                    onPressed: _isLoading
                        ? null
                        : () => _searchStock(_searchController.text),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                '💡 미국주식(예: AAPL) 또는 국내주식(예: 삼성전자, LS ELECTRIC, 005930)을 검색하세요',
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '다수의 최신 AI 모델이 동시에 동시 검증하고 있습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12),
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
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
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
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
                    _buildProcessStep('2', 'AI 분석',
                        'ChatGPT, Gemini, DeepSeek 등 다수 AI의 동시 분석'),
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
                const Icon(Icons.star, color: Colors.amber, size: 20),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        elevation: 4,
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsStockDetailPage(stock: stock),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 헤더 및 게이지 섹션
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stock.symbol,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (stock.changePercent! >= 0
                                            ? Colors.green
                                            : Colors.red)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: stock.changePercent! >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 게이지 위젯
                    Column(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 40,
                          child: CustomPaint(
                            painter: GaugePainter(
                              score: rec.verificationScore,
                              color:
                                  _getVerificationColor(rec.verificationScore),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${rec.verificationScore.toStringAsFixed(0)}점',
                          style: TextStyle(
                            color: _getVerificationColor(rec.verificationScore),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          rec.finalRecommendation,
                          style: TextStyle(
                            color: _getRecommendationColor(
                                rec.finalRecommendation),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. AI 투표 섹션 (Voting Plates)
                Text(
                  'AI 위원회 투표 결과',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: rec.models
                      .map((model) => _buildVotingPlate(model))
                      .toList(),
                ),

                // 전체 모델 오류 시 안내 배너
                if (rec.models.isNotEmpty &&
                    rec.models.every((m) => m.recommendation == 'Error'))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI 모델 API 키가 설정되지 않았습니다.\nVercel 환경변수에 OPENAI_API_KEY, GEMINI_API_KEY, ANTHROPIC_API_KEY, DEEPSEEK_API_KEY를 등록해주세요.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade800,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 16),

                // 3. AI 분석 요약
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '위원회 종합 의견',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rec.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 16),

                // 4. 관련 뉴스
                Row(
                  children: [
                    Icon(Icons.newspaper,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '관련 뉴스',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (_isLoadingNews) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: theme.colorScheme.primary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (!_isLoadingNews) _buildSentimentSummary(),
                const SizedBox(height: 8),
                if (_isLoadingNews)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('뉴스를 불러오는 중...',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                else if (_stockNews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('관련 뉴스가 없습니다',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                else
                  ..._stockNews.take(5).map((news) => _buildNewsItem(news)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentSummary() {
    final theme = Theme.of(context);
    int score = 0;
    int positiveCount = 0;
    int negativeCount = 0;

    for (final news in _stockNews) {
      if (news.sentiment == 'Positive') {
        score++;
        positiveCount++;
      } else if (news.sentiment == 'Negative') {
        score--;
        negativeCount++;
      }
    }

    if (_stockNews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined,
                color: Colors.grey.shade400, size: 18),
            const SizedBox(width: 8),
            Text('뉴스 감정 분석',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('데이터 없음',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
      );
    }

    Color signalColor;
    String signal;
    IconData signalIcon;

    if (score >= 3) {
      signal = '긍정적 흐름';
      signalColor = Colors.green[700]!;
      signalIcon = Icons.trending_up;
    } else if (score >= 1) {
      signal = '다소 긍정적';
      signalColor = Colors.green;
      signalIcon = Icons.sentiment_satisfied;
    } else if (score <= -3) {
      signal = '부정적 흐름';
      signalColor = Colors.red[700]!;
      signalIcon = Icons.trending_down;
    } else if (score <= -1) {
      signal = '다소 부정적';
      signalColor = Colors.red;
      signalIcon = Icons.sentiment_dissatisfied;
    } else {
      signal = '중립';
      signalColor = Colors.grey;
      signalIcon = Icons.remove_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: signalColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: signalColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(signalIcon, color: signalColor, size: 18),
              const SizedBox(width: 8),
              Text('뉴스 감정 분석',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(signal,
                  style: TextStyle(
                      color: signalColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (positiveCount > 0)
                Expanded(
                    flex: positiveCount,
                    child: Container(height: 3, color: Colors.green)),
              if (negativeCount > 0)
                Expanded(
                    flex: negativeCount,
                    child: Container(height: 3, color: Colors.red)),
              if (positiveCount == 0 && negativeCount == 0)
                Expanded(
                    child: Container(
                        height: 3, color: Colors.grey.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('호재 $positiveCount건',
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
              Text('악재 $negativeCount건',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(News news) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(news.link);
        if (uri != null && await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(news.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (news.source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(news.source,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            Icon(Icons.open_in_new,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _resolveDisplayName(String modelName) {
    final lowerName = modelName.toLowerCase();
    if (lowerName.contains('gemini')) return 'Gemini';
    if (lowerName.contains('llama 3.3') || lowerName.contains('llama-3.3')) {
      return 'Llama 3.3';
    }
    if (lowerName.contains('llama 3.1') ||
        lowerName.contains('llama-3.1') ||
        lowerName.contains('llama-3.1-8b')) {
      return 'Llama 3.1';
    }
    if (lowerName.contains('llama')) return 'Llama';
    if (lowerName.contains('qwen')) return 'Qwen';
    if (lowerName.contains('nemotron')) return 'Nemotron';
    if (lowerName.contains('gemma')) return 'Gemma 2';
    if (lowerName.contains('mixtral')) return 'Mixtral';
    if (lowerName.contains('mistral')) return 'Mistral';
    if (lowerName.contains('gpt') || lowerName.contains('openai')) {
      return 'ChatGPT';
    }
    if (lowerName.contains('claude') || lowerName.contains('anthropic')) {
      return 'Claude';
    }
    if (lowerName.contains('deepseek')) return 'DeepSeek';
    return modelName;
  }

  // reasoning 첫 문장 또는 최대 45자 요약
  String _abbreviateReasoning(String reasoning) {
    if (reasoning.isEmpty) return '';
    final newlineIdx = reasoning.indexOf('\n');
    final end =
        newlineIdx > 0 && newlineIdx <= 50 ? newlineIdx : reasoning.length;
    final first = reasoning.substring(0, end.clamp(0, 50));
    return reasoning.length > 50 ? '$first…' : first;
  }

  void _showReasoningSheet(AiModelResponse model, String displayName) {
    final color = _getRecommendationColor(model.recommendation);
    final isError = model.recommendation == 'Error';
    final fullText =
        model.fullResponse.isNotEmpty ? model.fullResponse : model.reasoning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(_getRecommendationIcon(model.recommendation),
                          color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            isError ? '분석 실패' : model.recommendation,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: color, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 전체 내용
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    fullText.isEmpty ? '분석 내용이 없습니다.' : fullText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVotingPlate(AiModelResponse model) {
    final theme = Theme.of(context);
    final color = _getRecommendationColor(model.recommendation);
    final displayName = _resolveDisplayName(model.modelName);
    final isError = model.recommendation == 'Error';
    final isMissing = model.reasoning.contains('미설정');
    final shortReason = _abbreviateReasoning(model.reasoning);

    return GestureDetector(
      onTap: () => _showReasoningSheet(model, displayName),
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      _getRecommendationIcon(model.recommendation),
                      color: color,
                      size: 30,
                    ),
                  ),
                ),
                // 탭 힌트 아이콘
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Icon(Icons.info_outline,
                      size: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              isError ? (isMissing ? '키 미설정' : '분석 실패') : model.recommendation,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shortReason,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRecommendationIcon(String recommendation) {
    switch (recommendation.toLowerCase()) {
      case 'buy':
      case 'strong buy':
      case '매수':
      case '강력 매수':
        return Icons.arrow_upward;
      case 'sell':
      case 'strong sell':
      case '매도':
      case '강력 매도':
        return Icons.arrow_downward;
      case 'hold':
      case '보유':
        return Icons.remove;
      case 'error':
        return Icons.warning_amber_rounded;
      default:
        return Icons.question_mark;
    }
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
      case 'error':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }
}

class GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    // 배경 아크
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      pi, // 180도에서 시작
      pi, // 180도 그림 (반원)
      false,
      bgPaint,
    );

    // 점수 아크
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      pi,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
