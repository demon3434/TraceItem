import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:traceitem_mobile/widgets/main_top_bar.dart';

void main() {
  Widget wrapTopBar(MainTopBar topBar) {
    return ShadApp(
      home: Scaffold(
        appBar: topBar,
        body: const SizedBox.shrink(),
      ),
    );
  }

  testWidgets('MainTopBar 未传 onSyncPressed 时不显示云朵同步按钮', (tester) async {
    await tester.pumpWidget(
      wrapTopBar(
        MainTopBar(
          title: '物品寻宝',
          onMenuClick: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.cloud), findsNothing);
    expect(find.byIcon(LucideIcons.cloudUpload), findsNothing);
  });

  testWidgets('MainTopBar 空闲态显示 cloud，点击触发同步并展示加载态防重入', (
    tester,
  ) async {
    var callCount = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(
      wrapTopBar(
        MainTopBar(
          title: '物品寻宝',
          onMenuClick: () {},
          onSyncPressed: () {
            callCount++;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cloudFinder = find.byIcon(LucideIcons.cloud);
    expect(cloudFinder, findsOneWidget);

    await tester.tap(cloudFinder);
    await tester.pump();
    expect(callCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 同步进行中再次点击不应重复触发
    await tester.tap(find.byType(CircularProgressIndicator));
    await tester.pump();
    expect(callCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.cloud), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

