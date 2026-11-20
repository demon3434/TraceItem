import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/api_service.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';
import 'package:traceitem_mobile/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeController 按 user_id 隔离主题且登出恢复默认', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.instance.switchUser(101);
    final secondThemeId = kDopamineThemes[1].id;
    await ThemeController.instance.selectTheme(secondThemeId);
    expect(ThemeController.instance.currentId, secondThemeId);

    // 切换至用户 202，应恢复默认主题而不串用用户 101 的配色
    await ThemeController.instance.switchUser(202);
    expect(ThemeController.instance.currentId, kDopamineThemes.first.id);

    // 切回用户 101，仍保留其个人偏好
    await ThemeController.instance.switchUser(101);
    expect(ThemeController.instance.currentId, secondThemeId);

    // 登出后恢复默认主题
    await ThemeController.instance.switchUser(null);
    expect(ThemeController.instance.currentId, kDopamineThemes.first.id);
  });

  test('Item 模型解析 version 与 409 冲突识别', () {
    final item = Item.fromJson({
      'id': 10,
      'user_id': 1,
      'house_id': 2,
      'room_id': 3,
      'name': '相机',
      'brand': 'Sony',
      'quantity': 1,
      'location_detail': '',
      'description': '',
      'version': 7,
    });
    expect(item.version, 7);

    final err409 = DioException(
      requestOptions: RequestOptions(path: '/items/10'),
      response: Response(
        requestOptions: RequestOptions(path: '/items/10'),
        statusCode: 409,
      ),
    );
    expect(ApiService.isConflictError(err409), isTrue);
  });
}

