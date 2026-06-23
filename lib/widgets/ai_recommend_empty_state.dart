import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a loading spinner, an error message with retry button, or an
/// informational empty-state depending on the combination of [isLoading],
/// [error] and [isEmpty].
class AiRecommendEmptyState extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;

  const AiRecommendEmptyState({
    super.key,
    required this.isLoading,
    this.error,
    required this.isEmpty,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // isEmpty == true
    final isLocalDev = kIsWeb &&
        (Uri.base.origin.contains('localhost') ||
            Uri.base.origin.contains('127.0.0.1'));

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
            isLocalDev ? 'AI 추천 서비스는 운영서버에서만 지원됩니다' : '최신 데이터를 불러오는 중입니다',
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
              onPressed: onRetry,
              child: const Text('새로고침'),
            ),
        ],
      ),
    );
  }
}
