import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';
import 'package:traceitem_mobile/models/models.dart';
import 'package:traceitem_mobile/widgets/home_filter_sheets.dart';
import 'package:traceitem_mobile/widgets/item_edit_pickers.dart';
import 'package:traceitem_mobile/widgets/space_action_sheet.dart';

Widget _wrapShadApp(Widget Function(BuildContext context) builder) {
  return ShadApp(
    theme: ShadThemeData(
      brightness: Brightness.light,
      colorScheme: ThemeController.instance.current.toShadColorScheme(),
    ),
    home: Scaffold(
      body: Builder(builder: builder),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final houses = [
    House(id: 1, userId: 1, name: '湖畔度假屋', icon: '🏡', sortOrder: 1),
    House(id: 2, userId: 1, name: '温馨小家', icon: '🏠', sortOrder: 2),
  ];
  final rooms = [
    Room(id: 10, userId: 1, houseId: 1, name: '休闲露台', icon: '🍷', sortOrder: 1),
    Room(id: 11, userId: 1, houseId: 1, name: '露营装备库', icon: '⛺', sortOrder: 2),
  ];
  final categories = [
    Category(id: 1, name: '户外露营', icon: '⛺', isActive: true, sortOrder: 1),
  ];

  testWidgets('HomeFilterSheets.showHousePicker 在 ShadApp 中正常渲染并切换房屋',
      (tester) async {
    House? picked;
    var called = false;

    await tester.pumpWidget(
      _wrapShadApp(
        (context) => Center(
          child: ShadButton(
            onPressed: () => HomeFilterSheets.showHousePicker(
              context,
              houses: houses,
              activeHouse: houses.first,
              showInactiveSpaces: false,
              onToggleShowInactive: (_) {},
              onSelected: (h) {
                called = true;
                picked = h;
              },
            ),
            child: const Text('打开空间切换'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开空间切换'));
    await tester.pumpAndSettle();

    expect(find.text('切换浏览空间'), findsOneWidget);
    expect(find.text('全部空间物品'), findsOneWidget);
    expect(find.text('湖畔度假屋'), findsOneWidget);
    expect(find.text('温馨小家'), findsOneWidget);

    await tester.tap(find.text('温馨小家'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(picked?.id, 2);
  });

  testWidgets('ItemEditPickers 三个抽屉在 ShadApp 中均无 Material 异常', (tester) async {
    House? pickedHouse;
    Room? pickedRoom;
    Category? pickedCategory;

    await tester.pumpWidget(
      _wrapShadApp(
        (context) => Column(
          children: [
            ShadButton(
              onPressed: () => ItemEditPickers.showHousePicker(
                context,
                houses: houses,
                selected: houses.first,
                onSelected: (h) => pickedHouse = h,
              ),
              child: const Text('选房屋'),
            ),
            ShadButton(
              onPressed: () => ItemEditPickers.showRoomPicker(
                context,
                rooms: rooms,
                selected: rooms.first,
                onSelected: (r) => pickedRoom = r,
              ),
              child: const Text('选房间'),
            ),
            ShadButton(
              onPressed: () => ItemEditPickers.showCategoryPicker(
                context,
                categories: categories,
                selected: null,
                onSelected: (c) => pickedCategory = c,
              ),
              child: const Text('选分类'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('选房屋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('温馨小家'));
    await tester.pumpAndSettle();
    expect(pickedHouse?.id, 2);

    await tester.tap(find.text('选房间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('露营装备库'));
    await tester.pumpAndSettle();
    expect(pickedRoom?.id, 11);

    await tester.tap(find.text('选分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('户外露营'));
    await tester.pumpAndSettle();
    expect(pickedCategory?.id, 1);
  });

  testWidgets('SpaceActionMenuSheet 在 ShadApp 中正常渲染并触发操作', (tester) async {
    var browsed = false;

    await tester.pumpWidget(
      _wrapShadApp(
        (context) => Center(
          child: ShadButton(
            onPressed: () => SpaceActionMenuSheet.show(
              context: context,
              icon: '🏡',
              title: '湖畔度假屋',
              subtitle: '共 2 个房间',
              onBrowse: () => browsed = true,
              onAddChild: () {},
              onEdit: () {},
              isActive: true,
              toggleLabel: '停用此房屋',
              onToggleStatus: () {},
              onDelete: () {},
              deleteLabel: '删除房屋',
            ),
            child: const Text('空间菜单'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('空间菜单'));
    await tester.pumpAndSettle();

    expect(find.text('查看空间物品'), findsOneWidget);
    expect(find.text('在此添加功能房间'), findsOneWidget);
    expect(find.text('删除房屋'), findsOneWidget);

    await tester.tap(find.text('查看空间物品'));
    await tester.pumpAndSettle();
    expect(browsed, isTrue);
  });
}

