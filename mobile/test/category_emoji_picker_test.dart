import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/category_emojis.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';
import 'package:traceitem_mobile/screens/category_manage_screen.dart';
import 'package:traceitem_mobile/widgets/category_emoji_picker_sheet.dart';

Widget _wrapShadApp(Widget child) {
  return ShadApp(
    theme: ShadThemeData(
      brightness: Brightness.light,
      colorScheme: ThemeController.instance.current.toShadColorScheme(),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('kCategoryEmojiGroups 严格包含 6 大分组共 192 款且与 Web 端 EmojiPickerPopover 一致',
      () {
    expect(kCategoryEmojiGroups.length, 6);
    expect(kCategoryEmojiTotalCount, 192);
    expect(
      kCategoryEmojiGroups.map((g) => g.name).toList(),
      ['toys', 'animals', 'sweets', 'home', 'art', 'nature'],
    );
    expect(
      kCategoryEmojiGroups.map((g) => g.label).toList(),
      ['玩具游乐', '动物萌宠', '零食美味', '生活居家', '文创装扮', '探索自然'],
    );
    for (final group in kCategoryEmojiGroups) {
      expect(group.emojis.length, 32, reason: '${group.name} 必须包含 32 款图标');
    }

    // 直接对比 shared/category_emojis.json 权威数据源，并校验 Web 端已接入 @shared
    final sharedFile = File('../shared/category_emojis.json');
    if (sharedFile.existsSync()) {
      final sharedJson =
          jsonDecode(sharedFile.readAsStringSync()) as Map<String, dynamic>;
      final sharedGroups = sharedJson['groups'] as List<dynamic>;
      expect(sharedGroups.length, 6);
      for (var i = 0; i < 6; i++) {
        final sg = sharedGroups[i] as Map<String, dynamic>;
        expect(
          kCategoryEmojiGroups[i].emojis,
          List<String>.from(sg['emojis'] as List),
          reason: '第 $i 组 (${kCategoryEmojiGroups[i].name}) 必须与 shared/category_emojis.json 完全一致',
        );
      }
    }
    final webFile = File('../web/src/components/ui/EmojiPickerPopover.vue');
    if (webFile.existsSync()) {
      expect(
        webFile.readAsStringSync(),
        contains('@shared/category_emojis.json'),
      );
    }
  });

  testWidgets('CategoryManageScreen 新建栏点击图标按钮打开 ShadSheet 并切换分组选图',
      (tester) async {
    await tester.pumpWidget(_wrapShadApp(const CategoryManageScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('📦'), findsOneWidget);
    await tester.tap(find.text('📦'));
    await tester.pumpAndSettle();

    expect(find.text('✨ 挑选分类小图标'), findsOneWidget);
    expect(find.textContaining('共 192 款精选图标'), findsOneWidget);

    await tester.tap(find.text('探索自然'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🌈'));
    await tester.pumpAndSettle();

    expect(find.text('✨ 挑选分类小图标'), findsNothing);
    expect(find.text('🌈'), findsOneWidget);
  });

  testWidgets('编辑抽屉内嵌套打开图标选择器选图后仅关闭内层抽屉并回显新图标', (tester) async {
    var currentIcon = '📦';
    var savedIcon = '';

    await tester.pumpWidget(
      _wrapShadApp(
        Builder(
          builder: (context) => Center(
            child: ShadButton(
              onPressed: () {
                var editIcon = currentIcon;
                showShadSheet<void>(
                  context: context,
                  side: ShadSheetSide.bottom,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setModalState) => ShadSheet(
                      title: const Text('修改物品分类'),
                      actions: [
                        ShadButton(
                          onPressed: () {
                            savedIcon = editIcon;
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('保存修改'),
                        ),
                      ],
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await CategoryEmojiPickerSheet.show(
                            ctx,
                            selectedEmoji: editIcon,
                          );
                          if (picked != null && ctx.mounted) {
                            setModalState(() => editIcon = picked);
                          }
                        },
                        child: Text(editIcon),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开编辑'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    expect(find.text('修改物品分类'), findsOneWidget);

    await tester.tap(find.text('📦'));
    await tester.pumpAndSettle();
    expect(find.text('✨ 挑选分类小图标'), findsOneWidget);

    await tester.tap(find.text('动物萌宠'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🦄'));
    await tester.pumpAndSettle();

    // 内层关闭、外层编辑抽屉保留且已回显🦄
    expect(find.text('✨ 挑选分类小图标'), findsNothing);
    expect(find.text('修改物品分类'), findsOneWidget);
    expect(find.text('🦄'), findsOneWidget);

    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(savedIcon, '🦄');
  });
}
