import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/network_route_manager.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController 7套多巴胺主题测试', () {
    test('内置7套多巴胺主题并支持切换与持久化', () async {
      SharedPreferences.setMockInitialValues({});
      expect(kDopamineThemes.length, 7);

      await ThemeController.instance.initFromStorage();
      expect(ThemeController.instance.currentId, 'warm-orange');

      await ThemeController.instance.selectTheme('cyber-neon');
      expect(ThemeController.instance.currentId, 'cyber-neon');
      expect(ThemeController.instance.current.name, '赛博霓虹');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.storageKey), 'cyber-neon');

      await ThemeController.instance.selectTheme('warm-orange');
    });
  });

  group('NetworkRouteManager 内外网双路由测试', () {
    test('URL规范化与私网IP识别', () {
      expect(
        NetworkRouteManager.normalizeUrl(' http://192.168.7.186:8085/// '),
        'http://192.168.7.186:8085',
      );
      expect(
        NetworkRouteManager.isPrivateNetwork('http://192.168.7.186:8085'),
        isTrue,
      );
      expect(
        NetworkRouteManager.isPrivateNetwork('http://10.0.0.5:8085'),
        isTrue,
      );
      expect(
        NetworkRouteManager.isPrivateNetwork('http://172.16.1.2:8085'),
        isTrue,
      );
      expect(
        NetworkRouteManager.isPrivateNetwork('https://trace.example.com'),
        isFalse,
      );
    });

    test('双地址保存、动态媒体路径解析与故障容灾降级', () async {
      SharedPreferences.setMockInitialValues({});
      final mgr = NetworkRouteManager.instance;
      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://trace.example.com',
        probeAfterSave: false,
      );

      expect(mgr.activeBaseUrl, 'http://192.168.7.186:8085');
      expect(mgr.currentRouteType, ActiveRouteType.intranet);
      expect(
        mgr.resolveMediaUrl('/api/media/file/images/2026/11/a.jpg'),
        'http://192.168.7.186:8085/api/media/file/images/2026/11/a.jpg',
      );

      final switched = await mgr.fallbackToExtranetIfNeeded(
        'http://192.168.7.186:8085',
      );
      expect(switched, isTrue);
      expect(mgr.activeBaseUrl, 'https://trace.example.com');
      expect(mgr.currentRouteType, ActiveRouteType.extranet);
      expect(
        mgr.resolveMediaUrl('/api/media/file/images/2026/11/a.jpg'),
        'https://trace.example.com/api/media/file/images/2026/11/a.jpg',
      );
    });
  });
}

