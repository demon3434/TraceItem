import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import '../models/models.dart';
import 'api_route_interceptor.dart';
import 'app_logger.dart';
import 'auth_storage.dart';
import 'media_cache_manager.dart';
import 'network_route_manager.dart';
import 'theme_controller.dart';

part 'api_service_media.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  late final Dio _dio;

  String? _token;
  User? _currentUser;
  VoidCallback? onUnauthorized;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    _dio.interceptors.add(
      ApiRouteInterceptor(
        dio: _dio,
        getToken: () => _token,
        onUnauthorizedLogout: () async {
          await logout();
          onUnauthorized?.call();
        },
      ),
    );
  }

  User? get currentUser => _currentUser;
  String? get token => _token;
  Dio get dio => _dio;
  Map<String, String> get authHeaders =>
      (_token != null && _token!.isNotEmpty)
          ? {'Authorization': 'Bearer $_token'}
          : const {};
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _currentUser?.role == 'admin';
  String get currentBaseUrl => NetworkRouteManager.instance.activeBaseUrl;

  String resolveMediaUrl(String? path) =>
      NetworkRouteManager.instance.resolveMediaUrl(path);

  String resolveAuthenticatedMediaUrl(String? path) {
    final resolved = resolveMediaUrl(path);
    if (resolved.isEmpty || _token == null || _token!.isEmpty) return resolved;
    final sep = resolved.contains('?') ? '&' : '?';
    return '$resolved${sep}token=${Uri.encodeQueryComponent(_token!)}';
  }

  Future<void> initFromStorage() async {
    await NetworkRouteManager.instance.initFromStorage();
    final session = await AuthStorage.loadSession();
    _token = session.token;
    _currentUser = session.user;
    if (_token != null && _token!.isNotEmpty && _currentUser != null) {
      await ThemeController.instance.switchUser(_currentUser!.id);
      await MediaCacheManager.instance.switchUser(_currentUser!.id);
    } else {
      await ThemeController.instance.switchUser(null);
    }
  }

  Future<void> setBaseUrl(String newUrl) async {
    final clean = NetworkRouteManager.normalizeUrl(newUrl);
    if (NetworkRouteManager.isPrivateNetwork(clean)) {
      await NetworkRouteManager.instance.saveRoutes(
        intranet: clean,
        extranet: NetworkRouteManager.instance.extranetUrl,
        probeAfterSave: false,
      );
    } else {
      await NetworkRouteManager.instance.saveRoutes(
        intranet: NetworkRouteManager.instance.intranetUrl,
        extranet: clean,
        probeAfterSave: false,
      );
    }
  }

  Future<bool> checkHealth([String? testUrl]) async {
    final target = testUrl ?? currentBaseUrl;
    return NetworkRouteManager.instance.checkUrlHealthy(target, timeoutMs: 3500);
  }

  Future<bool> getAllowPublicRegistration() async {
    if (currentBaseUrl.isEmpty) return false;
    try {
      final res = await _dio.get('/auth/config');
      final data = res.data['data'] as Map<String, dynamic>?;
      return data?['allow_public_registration'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<User> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    // 非 Admin 阶段：若识别到 admin 账号直接返回而不写入本地会话
    if (user.role == 'admin') {
      return user;
    }

    _token = data['access_token'] as String;
    _currentUser = user;

    await AuthStorage.saveSession(
      _token!,
      data['user'] as Map<String, dynamic>,
    );
    await ThemeController.instance.switchUser(user.id);
    await MediaCacheManager.instance.switchUser(user.id);
    return _currentUser!;
  }

  Future<User> register({
    required String username,
    required String nickname,
    required String password,
  }) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'nickname': nickname,
      'password': password,
    });
    return login(username, password);
  }

  Future<User> updateMe({String? nickname, String? password}) async {
    final res = await _dio.put('/auth/me', data: {
      if (nickname != null) 'nickname': nickname,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    final userMap = res.data['data'] as Map<String, dynamic>;
    _currentUser = User.fromJson(userMap);
    await AuthStorage.saveUserOnly(userMap);
    return _currentUser!;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await AuthStorage.clearSession();
    await MediaCacheManager.instance.switchUser(null);
    await ThemeController.instance.switchUser(null);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AppLogger.instance.clear();
  }

  Future<List<House>> getHouses() async {
    final res = await _dio.get('/houses');
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => House.fromJson(e)).toList();
  }

  Future<House> createHouse(String name, String icon, [int sortOrder = 0]) async {
    final res = await _dio.post('/houses', data: {
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    });
    return House.fromJson(res.data['data']);
  }

  Future<House> updateHouse(
    int id, {
    String? name,
    String? icon,
    int? sortOrder,
  }) async {
    final res = await _dio.put('/houses/$id', data: {
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
    return House.fromJson(res.data['data']);
  }

  Future<void> toggleHouseStatus(int id, bool isActive) async {
    await _dio.patch(
      '/houses/$id/status',
      queryParameters: {'is_active': isActive},
    );
  }

  Future<void> deleteHouse(int id) async {
    await _dio.delete('/houses/$id');
  }

  Future<List<House>> reorderHouses(List<int> orderedIds) async {
    final res = await _dio.put('/houses/reorder', data: {
      'ordered_ids': orderedIds,
    });
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => House.fromJson(e)).toList();
  }

  Future<List<Room>> getRooms([int? houseId]) async {
    final res = await _dio.get(
      '/rooms',
      queryParameters: houseId != null ? {'house_id': houseId} : null,
    );
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => Room.fromJson(e)).toList();
  }

  Future<Room> createRoom(
    String name,
    String icon,
    int houseId, [
    int sortOrder = 0,
  ]) async {
    final res = await _dio.post('/rooms', data: {
      'name': name,
      'icon': icon,
      'house_id': houseId,
      'sort_order': sortOrder,
    });
    return Room.fromJson(res.data['data']);
  }

  Future<Room> updateRoom(
    int id, {
    int? houseId,
    String? name,
    String? icon,
    int? sortOrder,
  }) async {
    final res = await _dio.put('/rooms/$id', data: {
      if (houseId != null) 'house_id': houseId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
    return Room.fromJson(res.data['data']);
  }

  Future<void> toggleRoomStatus(int id, bool isActive) async {
    await _dio.patch(
      '/rooms/$id/status',
      queryParameters: {'is_active': isActive},
    );
  }

  Future<void> deleteRoom(int id) async {
    await _dio.delete('/rooms/$id');
  }

  Future<List<Room>> reorderRooms(int houseId, List<int> orderedIds) async {
    final res = await _dio.put('/rooms/reorder', data: {
      'house_id': houseId,
      'ordered_ids': orderedIds,
    });
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => Room.fromJson(e)).toList();
  }

  Future<List<Category>> getCategories({bool includeInactive = false}) async {
    final res = await _dio.get(
      '/items/categories',
      queryParameters: {'include_inactive': includeInactive},
    );
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => Category.fromJson(e)).toList();
  }

  Future<Category> createCategory(
    String name,
    String icon,
    int sortOrder,
  ) async {
    final res = await _dio.post('/items/categories', data: {
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': true,
    });
    return Category.fromJson(res.data['data']);
  }

  Future<Category> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    final res = await _dio.put('/items/categories/$id', data: {
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
    });
    return Category.fromJson(res.data['data']);
  }

  Future<void> toggleCategoryStatus(int id, bool isActive) async {
    await _dio.patch(
      '/items/categories/$id/status',
      queryParameters: {'is_active': isActive},
    );
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete('/items/categories/$id');
  }

  Future<List<String>> suggestTags(String q) async {
    final res = await _dio.get(
      '/items/tags/suggest',
      queryParameters: {'q': q, 'limit': 8},
    );
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> getItemsPaginated({
    int? houseId,
    int? roomId,
    int? categoryId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final res = await _dio.get('/items', queryParameters: {
      if (houseId != null) 'house_id': houseId,
      if (roomId != null) 'room_id': roomId,
      if (categoryId != null) 'category_id': categoryId,
      'page': page,
      'page_size': pageSize,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final list = (data['items'] as List<dynamic>)
        .map((e) => Item.fromJson(e))
        .toList();
    final total = data['pagination']['total'] as int? ?? 0;
    return {'items': list, 'total': total};
  }

  Future<Item> getItemDetail(int itemId) async {
    final res = await _dio.get('/items/$itemId');
    return Item.fromJson(res.data['data']);
  }

  Future<List<Item>> searchItems(String q) async {
    final res = await _dio.get('/search', queryParameters: {'q': q});
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => Item.fromJson(e)).toList();
  }

  Future<Item> createItem(Map<String, dynamic> data) async {
    final res = await _dio.post('/items', data: data);
    return Item.fromJson(res.data['data']);
  }

  Future<Item> updateItem(int itemId, Map<String, dynamic> data) async {
    final res = await _dio.put('/items/$itemId', data: data);
    return Item.fromJson(res.data['data']);
  }

  Future<void> deleteItem(
    int itemId, {
    int? expectedVersion,
    bool force = false,
    String? clientOpUuid,
  }) async {
    await _dio.delete(
      '/items/$itemId',
      queryParameters: {
        if (expectedVersion != null) 'expected_version': expectedVersion,
        if (force) 'force': true,
        if (clientOpUuid != null) 'client_op_uuid': clientOpUuid,
      },
    );
  }

  static bool isConflictError(Object error) =>
      error is DioException && error.response?.statusCode == 409;

  static bool isNotFoundError(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  static Map<String, dynamic>? extractConflictData(Object error) {
    if (!isConflictError(error)) return null;
    final body = (error as DioException).response?.data;
    if (body is Map<String, dynamic> && body['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }

  static bool isNetworkError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.unknown;
    }
    return error.toString().contains('SocketException');
  }

  static String formatDioError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
      if (error.error != null) return error.error.toString();
      return error.message ?? '网络请求失败';
    }
    return error.toString();
  }
}
