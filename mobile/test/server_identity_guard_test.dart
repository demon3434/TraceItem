import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/api_service.dart';
import 'package:traceitem_mobile/core/network_route_manager.dart';
import 'package:traceitem_mobile/core/server_identity_guard.dart';

class _FakeHealthAdapter implements HttpClientAdapter {
  final String instanceId;
  _FakeHealthAdapter(this.instanceId);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'message': 'healthy',
        'data': {
          'status': 'online',
          'server_instance_id': instanceId,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NetworkRouteManager.instance.configureForTest();
    ApiService.instance.onServerInstanceChanged = null;
  });

  test('testUrlLatency 检测到不同 server_instance_id 时触发实例变更回调并更新指纹', () async {
    SharedPreferences.setMockInitialValues({
      'traceitem_last_server_instance_id': 'wankeyun-51-uuid',
    });

    var changedTriggered = false;
    ApiService.instance.onServerInstanceChanged = () {
      changedTriggered = true;
    };

    final dio = Dio()..httpClientAdapter = _FakeHealthAdapter('server-186-uuid');
    NetworkRouteManager.instance.configureForTest(probeDio: dio);

    final res = await NetworkRouteManager.instance
        .testUrlLatency('http://192.168.7.186:8085');

    expect(res.ok, isTrue);
    expect(changedTriggered, isTrue);
    expect(
      await ServerIdentityGuard.instance.getLastServerInstanceId(),
      'server-186-uuid',
    );
  });

  test('testUrlLatency 检测到相同 server_instance_id 时不触发重置', () async {
    SharedPreferences.setMockInitialValues({
      'traceitem_last_server_instance_id': 'wankeyun-51-uuid',
    });

    var changedTriggered = false;
    ApiService.instance.onServerInstanceChanged = () {
      changedTriggered = true;
    };

    final dio = Dio()..httpClientAdapter = _FakeHealthAdapter('wankeyun-51-uuid');
    NetworkRouteManager.instance.configureForTest(probeDio: dio);

    final res = await NetworkRouteManager.instance
        .testUrlLatency('http://192.168.7.51:8085');

    expect(res.ok, isTrue);
    expect(changedTriggered, isFalse);
  });
}

