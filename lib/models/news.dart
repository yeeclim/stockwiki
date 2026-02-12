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
    // FMP API 응답 형식에 맞게 수정
    return News(
      title: json['title'] ?? json['headline'] ?? '',
      description: json['description'] ?? json['text'] ?? json['summary'] ?? '',
      link: json['link'] ?? json['url'] ?? '',
      source: json['source'] ?? json['site'] ?? '',
      publishedAt: json['publishedAt'] ?? json['publishedDate'] ?? json['published_at'] ?? json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'link': link,
      'source': source,
      'publishedAt': publishedAt,
    };
  }
}
