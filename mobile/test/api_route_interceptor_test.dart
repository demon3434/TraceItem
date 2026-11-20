import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/api_route_interceptor.dart';
import 'package:traceitem_mobile/core/network_route_manager.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _FakeHttpAdapter(this.handler);

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

ResponseBody _jsonResp(int status, Map<String, dynamic> data) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiRouteInterceptor 容灾与 401 防误杀测试', () {
    test('私有内网401回退外网重放成功时不触发登出', () async {
      SharedPreferences.setMockInitialValues({});
      final mgr = NetworkRouteManager.instance;
      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://trace.example.com',
        probeAfterSave: false,
      );

      var logoutCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpAdapter((opts) async {
        if (opts.uri.host == '192.168.7.186') {
          return _jsonResp(401, {'detail': 'router auth'});
        }
        return _jsonResp(200, {'ok': true});
      });
      dio.interceptors.add(
        ApiRouteInterceptor(
          dio: dio,
          getToken: () => 'valid-token',
          onUnauthorizedLogout: () async => logoutCount++,
          routeManager: mgr,
        ),
      );

      final res = await dio.get('/houses');
      expect(res.statusCode, 200);
      expect(logoutCount, 0);
      expect(mgr.activeBaseUrl, 'https://trace.example.com');
    });

    test('私有内网401回退外网后仍返回401时触发登出', () async {
      SharedPreferences.setMockInitialValues({});
      final mgr = NetworkRouteManager.instance;
      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://trace.example.com',
        probeAfterSave: false,
      );

      var logoutCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpAdapter((opts) async {
        return _jsonResp(401, {'detail': 'expired'});
      });
      dio.interceptors.add(
        ApiRouteInterceptor(
          dio: dio,
          getToken: () => 'expired-token',
          onUnauthorizedLogout: () async => logoutCount++,
          routeManager: mgr,
        ),
      );

      await expectLater(
        () => dio.get('/houses'),
        throwsA(isA<DioException>()),
      );
      expect(logoutCount, 1);
      expect(mgr.activeBaseUrl, 'https://trace.example.com');
    });

    test('sendTimeout 与 unknown SocketException 触发容灾切换至外网并重放', () async {
      SharedPreferences.setMockInitialValues({});
      final mgr = NetworkRouteManager.instance;
      await mgr.saveRoutes(
        intranet: 'http://192.168.7.186:8085',
        extranet: 'https://trace.example.com',
        probeAfterSave: false,
      );

      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpAdapter((opts) async {
        if (opts.uri.host == '192.168.7.186') {
          throw DioException(
            requestOptions: opts,
            type: DioExceptionType.unknown,
            error: const SocketException('Network is unreachable'),
          );
        }
        return _jsonResp(200, {'ok': true});
      });
      dio.interceptors.add(
        ApiRouteInterceptor(
          dio: dio,
          getToken: () => 'valid-token',
          onUnauthorizedLogout: () async {},
          routeManager: mgr,
        ),
      );

      final res = await dio.get('/items');
      expect(res.statusCode, 200);
      expect(mgr.activeBaseUrl, 'https://trace.example.com');
    });
  });
}

