import 'stock.dart';

class CommitteeRecommendation {
  final Stock stock;
  final List<AiModelResponse> models;
  final double verificationScore;
  final String agreement;
  final String finalRecommendation;
  final String summary;

  CommitteeRecommendation({
    required this.stock,
    required this.models,
    required this.verificationScore,
    required this.agreement,
    required this.finalRecommendation,
    required this.summary,
  });
}

class AiModelResponse {
  final String modelName;
  final String recommendation;
  final String reasoning;

  AiModelResponse({
    required this.modelName,
    required this.recommendation,
    required this.reasoning,
  });

  factory AiModelResponse.fromJson(Map<String, dynamic> json) {
    return AiModelResponse(
      modelName: json['modelName'] ?? 'Unknown',
      recommendation: json['recommendation'] ?? 'Hold',
      reasoning: json['reasoning'] ?? '',
    );
  }
}
