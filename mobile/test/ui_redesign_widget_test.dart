import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/navigation_models.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';
import 'package:traceitem_mobile/models/models.dart';
import 'package:traceitem_mobile/screens/item_detail_screen.dart';
import 'package:traceitem_mobile/screens/login_screen.dart';
import 'package:traceitem_mobile/screens/settings/theme_settings_screen.dart';
import 'package:traceitem_mobile/widgets/main_drawer_content.dart';
import 'package:traceitem_mobile/widgets/main_top_bar.dart';

Widget _wrapApp(Widget child) {
  return ShadApp(
    theme: ShadThemeData(
      brightness: Brightness.light,
      colorScheme: ThemeController.instance.current.toShadColorScheme(),
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LoginScreen 无快捷登录按钮且包含未配置服务提示', (tester) async {
    await tester.pumpWidget(_wrapApp(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('爱丽丝'), findsNothing);
    expect(find.text('鲍勃'), findsNothing);
    expect(find.text('进入空间账本'), findsOneWidget);
    expect(find.textContaining('配置服务网址'), findsOneWidget);
  });

  testWidgets('MainDrawerContent 仅包含用户业务菜单且右上角齿轮进设置', (tester) async {
    MobileDestination? tapped;
    var openedSettings = false;

    await tester.pumpWidget(
      _wrapApp(
        Scaffold(
          body: MainDrawerContent(
            user: User(
              id: 1,
              username: 'alice',
              nickname: '爱丽丝',
              role: 'user',
              isActive: true,
            ),
            currentDestination: MobileDestination.itemsHome,
            onSelectDestination: (d) => tapped = d,
            onNavigateToSettings: () => openedSettings = true,
            onCloseDrawer: () {},
          ),
        ),
      ),
    );

    expect(find.text('物品寻宝'), findsOneWidget);
    expect(find.text('登记收纳'), findsOneWidget);
    expect(find.text('房屋与房间'), findsOneWidget);
    expect(find.text('物品分类'), findsOneWidget);

    await tester.tap(find.text('房屋与房间'));
    expect(tapped, MobileDestination.spaceManage);

    await tester.tap(find.byTooltip('系统设置'));
    expect(openedSettings, isTrue);
  });

  testWidgets('MainTopBar 一级菜单与二级返回图标切换', (tester) async {
    var backClicked = false;
    await tester.pumpWidget(
      _wrapApp(
        Scaffold(
          appBar: MainTopBar(
            title: '多巴胺主题配色 🎨',
            canNavigateBack: true,
            onMenuClick: () {},
            onNavigateBack: () => backClicked = true,
          ),
          body: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('返回'));
    expect(backClicked, isTrue);
  });

  testWidgets('ThemeSettingsScreen 展示全部7套多巴胺主题', (tester) async {
    await tester.pumpWidget(
      _wrapApp(const Scaffold(body: ThemeSettingsScreen())),
    );
    for (final t in kDopamineThemes) {
      await tester.scrollUntilVisible(
        find.text(t.name),
        150,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(t.name), findsOneWidget);
    }
  });

  testWidgets('ItemDetailScreen 展示详情与删除 ShadDialog 确认框', (tester) async {
    final sample = Item(
      id: 99,
      userId: 1,
      houseId: 1,
      roomId: 1,
      name: '儿童退热贴',
      brand: '小林制药',
      quantity: 3,
      locationDetail: '客厅医药箱上层',
      description: '发烧应急使用',
      pathDisplay: '温馨小家 > 大客厅',
      tags: [Tag(id: 1, name: '应急')],
    );

    await tester.pumpWidget(
      _wrapApp(
        ItemDetailScreen(
          item: sample,
          houses: const [],
          rooms: const [],
          categories: const [],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('儿童退热贴'), findsOneWidget);
    expect(find.text('# 应急'), findsOneWidget);
    expect(find.text('删除物品'), findsOneWidget);

    await tester.tap(find.text('删除物品'));
    await tester.pumpAndSettle();
    expect(find.text('确认删除该物品？'), findsOneWidget);
  });
}
