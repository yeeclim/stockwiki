// lib/models/news.dart

class News {
  final String title;
  final String description;
  final String link;
  final String source;
  final String? publishedAt;
  final String sentiment; // 'Positive', 'Negative', 'Neutral'

  // url은 link의 별칭으로 사용
  String get url => link;

  News({
    required this.title,
    required this.description,
    required this.link,
    required this.source,
    this.publishedAt,
    this.sentiment = 'Neutral',
  });

  factory News.fromJson(Map<String, dynamic> json) {
    final title = json['title'] ?? json['headline'] ?? '';
    final description =
        json['description'] ?? json['text'] ?? json['summary'] ?? '';
    // API가 sentiment를 내려주면 우선 사용, 없으면 키워드 분석
    final rawSentiment = json['sentiment']?.toString() ?? '';
    final sentiment = rawSentiment.isNotEmpty
        ? rawSentiment
        : analyzeSentiment(title, description);
    return News(
      title: title,
      description: description,
      link: json['link'] ?? json['url'] ?? '',
      source: json['source'] ?? json['site'] ?? '',
      publishedAt: json['publishedAt'] ??
          json['publishedDate'] ??
          json['published_at'] ??
          json['date'] ??
          '',
      sentiment: sentiment,
    );
  }

  // 제목+설명 키워드 기반 감정 분석
  static String analyzeSentiment(String title, String description) {
    final text = '$title $description'.toLowerCase();

    // ── 한국어 호재 키워드 ──
    const positiveKo = [
      '급등',
      '상승',
      '올랐',
      '올라',
      '오른다',
      '증가',
      '성장',
      '흑자',
      '수익',
      '이익',
      '영업익 증가',
      '호실적',
      '상향',
      '강세',
      '신고가',
      '최고가',
      '반등',
      '회복',
      '개선',
      '수주',
      '계약',
      '협력',
      '파트너십',
      '확장',
      '출시',
      '승인',
      '허가',
      '배당',
      '자사주',
      '매수',
      '호재',
      '긍정',
      '기대',
      '돌파',
      '역대 최대',
      '흑자 전환',
      '턴어라운드',
      '목표가 상향',
      '어닝 서프라이즈',
      '사상 최고',
      '최대 실적',
      '매출 증가',
      '순이익 증가',
      '수익성 개선',
      '신규 수주',
    ];

    // ── 한국어 악재 키워드 ──
    const negativeKo = [
      '하락',
      '급락',
      '떨어졌',
      '내렸',
      '내려',
      '감소',
      '적자',
      '손실',
      '부진',
      '하향',
      '약세',
      '신저가',
      '최저가',
      '위기',
      '우려',
      '경고',
      '소송',
      '제재',
      '벌금',
      '리콜',
      '결함',
      '사고',
      '파업',
      '구조조정',
      '감원',
      '해고',
      '부채',
      '부도',
      '파산',
      '횡령',
      '비리',
      '악재',
      '부정',
      '실망',
      '충격',
      '폭락',
      '적자 전환',
      '어닝 쇼크',
      '실적 부진',
      '목표가 하향',
      '매도',
      '매출 감소',
      '영업손실',
      '수익성 악화',
      '하향 조정',
      '리스크',
      '불확실',
    ];

    // ── 영어 호재 키워드 ──
    const positiveEn = [
      'surge',
      'soar',
      'rally',
      'rise',
      'gain',
      'growth',
      'profit',
      'record',
      'beat',
      'exceed',
      'upgrade',
      'buy',
      'outperform',
      'bullish',
      'strong',
      'expansion',
      'partnership',
      'deal',
      'contract',
      'approve',
      'launch',
      'dividend',
      'buyback',
      'positive',
      'optimistic',
      'breakthrough',
      'earnings beat',
      'revenue growth',
      'all-time high',
    ];

    // ── 영어 악재 키워드 ──
    const negativeEn = [
      'plunge',
      'crash',
      'fall',
      'drop',
      'decline',
      'loss',
      'miss',
      'downgrade',
      'sell',
      'underperform',
      'bearish',
      'weak',
      'warning',
      'lawsuit',
      'fine',
      'recall',
      'layoff',
      'bankruptcy',
      'fraud',
      'negative',
      'concern',
      'risk',
      'uncertainty',
      'disappointing',
      'earnings miss',
      'revenue decline',
      'all-time low',
    ];

    int pos = 0;
    int neg = 0;

    for (final w in positiveKo) {
      if (text.contains(w)) pos++;
    }
    for (final w in negativeKo) {
      if (text.contains(w)) neg++;
    }
    for (final w in positiveEn) {
      if (text.contains(w)) pos++;
    }
    for (final w in negativeEn) {
      if (text.contains(w)) neg++;
    }

    if (pos > neg) return 'Positive';
    if (neg > pos) return 'Negative';
    return 'Neutral';
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'link': link,
      'source': source,
      'publishedAt': publishedAt,
      'sentiment': sentiment,
    };
  }
}
