import 'dart:io';
import 'package:dio/dio.dart';
import 'app_logger.dart';
import 'constants.dart';
import 'network_route_manager.dart';

/// Dio 路由注入、超时容灾降级与私有内网 401 防误杀拦截器
class ApiRouteInterceptor extends Interceptor {
  final Dio dio;
  final String? Function() getToken;
  final Future<void> Function() onUnauthorizedLogout;
  final NetworkRouteManager routeManager;

  bool _handlingUnauthorized = false;

  ApiRouteInterceptor({
    required this.dio,
    required this.getToken,
    required this.onUnauthorizedLogout,
    NetworkRouteManager? routeManager,
  }) : routeManager = routeManager ?? NetworkRouteManager.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final activeBase = routeManager.activeBaseUrl;
    if (activeBase.isEmpty) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: '请先配置服务器地址',
          type: DioExceptionType.connectionError,
        ),
      );
    }
    options.baseUrl = '$activeBase${AppConstants.apiPrefix}';
    final token = getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    AppLogger.instance.net('HTTP', '--> ${options.method} ${options.path}');
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.instance.net(
      'HTTP',
      '<-- ${response.statusCode} ${response.requestOptions.path}',
    );
    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    AppLogger.instance.e(
      'HTTP',
      'ERR ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.path}: ${err.message} | data=${err.response?.data}',
    );

    final statusCode = err.response?.statusCode;
    final reqPath = err.requestOptions.path;
    final isAuthEndpoint =
        reqPath.contains('/auth/login') || reqPath.contains('/auth/register');
    final alreadyRetried = err.requestOptions.extra['_retried'] == true;
    final reqBase =
        err.requestOptions.baseUrl.replaceAll(RegExp(r'/api$'), '');

    if (statusCode == 401 && !isAuthEndpoint) {
      // 私有内网地址返回 401 且尚未容灾重试时，先尝试切外网重放，防止外部 WiFi 同 IP 设备误杀登录态
      if (!alreadyRetried && NetworkRouteManager.isPrivateNetwork(reqBase)) {
        final switched = await routeManager.fallbackToExtranetIfNeeded(reqBase);
        if (switched) {
          final opts = err.requestOptions;
          opts.extra['_retried'] = true;
          opts.baseUrl =
              '${routeManager.activeBaseUrl}${AppConstants.apiPrefix}';
          try {
            final response = await dio.fetch(opts);
            return handler.resolve(response);
          } catch (retryErr) {
            if (retryErr is DioException) {
              return handler.next(retryErr);
            }
          }
        }
      }

      await _triggerLogoutOnce();
      return handler.next(err);
    }

    if (_isTimeoutOrNetworkError(err) && !alreadyRetried) {
      final switched = await routeManager.fallbackToExtranetIfNeeded(reqBase);
      if (switched) {
        final opts = err.requestOptions;
        opts.extra['_retried'] = true;
        opts.baseUrl =
            '${routeManager.activeBaseUrl}${AppConstants.apiPrefix}';
        try {
          final response = await dio.fetch(opts);
          return handler.resolve(response);
        } catch (retryErr) {
          if (retryErr is DioException) {
            return handler.next(retryErr);
          }
        }
      }
    }

    return handler.next(err);
  }

  bool _isTimeoutOrNetworkError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    if (err.type == DioExceptionType.unknown) {
      if (err.error is SocketException) return true;
      final msg = err.message ?? '';
      return msg.contains('SocketException') ||
          msg.contains('Connection') ||
          msg.contains('Network is unreachable');
    }
    return false;
  }

  Future<void> _triggerLogoutOnce() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      await onUnauthorizedLogout();
    } finally {
      _handlingUnauthorized = false;
    }
  }
}

