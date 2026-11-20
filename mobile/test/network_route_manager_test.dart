import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/network_route_manager.dart';

class _FakeProbeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _FakeProbeAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

ResponseBody _jsonBody(int status, String text) {
  return ResponseBody.fromString(
    jsonEncode({'ok': status >= 200 && status < 300, 'msg': text}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NetworkRouteManager.instance.configureForTest();
  });

  group('NetworkRouteManager 路由切换与探针测试', () {
    test('蜂窝网络快轨跳过内网探测直接切至外网', () async {
      SharedPreferences.setMockInitialValues({});
      var probeCalled = false;
      final dio = Dio()
        ..httpClientAdapter = _FakeProbeAdapter((opts) async {
          probeCalled = true;
          return _jsonBody(200, 'ok');
        });

      final mgr = NetworkRouteManager.instance;
      mgr.configureForTest(
        probeDio: dio,
        connectivityChecker: () async => [ConnectivityResult.mobile],
      );

      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://trace.example.com',
        probeAfterSave: false,
      );
      expect(mgr.activeBaseUrl, 'http://192.168.7.186:8085');

      final active = await mgr.detectAndSwitchBestRoute();
      expect(active, 'https://trace.example.com');
      expect(mgr.currentRouteType, ActiveRouteType.extranet);
      expect(probeCalled, isFalse);
    });

    test('WiFi下内网不可达且外网慢响应(>1.5s)走根路径兜底时成功切至外网', () async {
      SharedPreferences.setMockInitialValues({});
      final requestedPaths = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _FakeProbeAdapter((opts) async {
          requestedPaths.add(opts.uri.toString());
          if (opts.uri.host == '192.168.7.186') {
            throw DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
            );
          }
          if (opts.uri.path == '/api/health' || opts.uri.path == '/health') {
            return _jsonBody(404, 'not found');
          }
          // 模拟公网 TLS + WAF 延迟 > 1500ms（但 < 3500ms）
          await Future.delayed(const Duration(milliseconds: 1700));
          expect(opts.connectTimeout?.inMilliseconds, 3500);
          expect(opts.receiveTimeout?.inMilliseconds, 3500);
          return _jsonBody(200, 'ok');
        });

      final mgr = NetworkRouteManager.instance;
      mgr.configureForTest(
        probeDio: dio,
        connectivityChecker: () async => [ConnectivityResult.wifi],
      );

      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://waf.example.com',
        probeAfterSave: false,
      );

      final active = await mgr.detectAndSwitchBestRoute();
      expect(active, 'https://waf.example.com');
      expect(mgr.currentRouteType, ActiveRouteType.extranet);
      expect(requestedPaths, contains('https://waf.example.com/'));
    });

    test('内网恢复后重新探测可切回内网且保持状态幂等', () async {
      SharedPreferences.setMockInitialValues({});
      var intraUp = false;
      final dio = Dio()
        ..httpClientAdapter = _FakeProbeAdapter((opts) async {
          if (opts.uri.host == '192.168.7.186') {
            if (!intraUp) {
              throw DioException(
                requestOptions: opts,
                type: DioExceptionType.connectionError,
              );
            }
            return _jsonBody(200, 'ok');
          }
          return _jsonBody(200, 'ok');
        });

      final mgr = NetworkRouteManager.instance;
      mgr.configureForTest(
        probeDio: dio,
        connectivityChecker: () async => [ConnectivityResult.wifi],
      );

      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://waf.example.com',
        probeAfterSave: false,
      );

      expect(await mgr.detectAndSwitchBestRoute(), 'https://waf.example.com');
      intraUp = true;
      expect(
        await mgr.detectAndSwitchBestRoute(),
        'http://192.168.7.186:8085',
      );
      expect(mgr.currentRouteType, ActiveRouteType.intranet);
    });
  });
}

