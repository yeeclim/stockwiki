// lib/models/news.dart

class News {
  final String title;
  final String description;
  final String link;
  final String source;
  final String? publishedAt;

  News({
    required this.title,
    required this.description,
    required this.link,
    required this.source,
    this.publishedAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      link: json['link'] ?? json['url'] ?? '',
      source: json['source'] ?? '',
      publishedAt: json['publishedAt'] ?? json['published_at'],
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
