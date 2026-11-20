import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:traceitem_mobile/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen 开启 deferInitialRemoteFetch 时冷启动不展示全屏阻塞加载圈', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: HomeScreen(deferInitialRemoteFetch: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

