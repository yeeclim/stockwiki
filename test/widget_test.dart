// StockWiki 앱 기본 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stockwiki/main.dart';

void main() {
  testWidgets('StockWiki 앱이 정상적으로 시작되는지', (WidgetTester tester) async {
    // 앱 빌드 및 프레임 트리거
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // StockWiki 텍스트가 있는지 확인
    expect(find.text('StockWiki'), findsOneWidget);
  });
}
