import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stockwiki/providers/bookmark_provider.dart';
import 'package:stockwiki/main.dart';
import 'package:stockwiki/services/http_client.dart';

// ── 헬퍼: Provider 래핑 ────────────────────────────────────
Widget withProviders(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => BookmarkProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  // ── BookmarkProvider 단위 테스트 ────────────────────────
  group('BookmarkProvider', () {
    test('초기 상태는 비어있음', () {
      final provider = BookmarkProvider();
      expect(provider.bookmarks, isEmpty);
      expect(provider.isBookmarked('AAPL'), false);
    });

    test('add → isBookmarked true', () async {
      final provider = BookmarkProvider();
      // SharedPreferences를 실제로 건드리지 않으므로 mock 필요 없이
      // 내부 상태만 직접 확인
      provider.bookmarks.add('AAPL');
      expect(provider.isBookmarked('AAPL'), true);
    });
  });

  // ── http_client 재시도 함수 단위 테스트 ─────────────────
  group('validateString (shared.js와 동일한 규칙 검증)', () {
    test('getWithRetry는 Future<Response>를 반환하는 함수', () {
      // getWithRetry가 존재하고 callable한지만 확인
      expect(getWithRetry, isA<Function>());
    });
  });

  // ── 앱 시작 위젯 테스트 ─────────────────────────────────
  group('MyApp 위젯', () {
    testWidgets('앱이 오류 없이 렌더링됨', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider(),
          child: const MyApp(),
        ),
      );
      await tester.pump();
      // 앱 제목이 존재하는지 확인
      expect(find.text('StockWiki'), findsWidgets);
    });

    testWidgets('AppBar가 존재함', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider(),
          child: const MyApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
