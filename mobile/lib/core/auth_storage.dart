import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 认证凭据安全存储封装（支持旧版 SharedPreferences 明文 Token 无感迁移）
class AuthStorage {
  static const String _kTokenKey = 'auth_token';
  static const String _kUserKey = 'auth_user';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<({String? token, User? user})> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? token;
    try {
      token = await _secureStorage.read(key: _kTokenKey);
    } catch (_) {
      token = null;
    }

    // 兼容迁移：若安全存储为空，检查旧版 SharedPreferences 明文 Token
    final legacyToken = prefs.getString(_kTokenKey);
    if ((token == null || token.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty) {
      token = legacyToken;
      try {
        await _secureStorage.write(key: _kTokenKey, value: legacyToken);
        await prefs.remove(_kTokenKey);
      } catch (_) {}
    } else if (legacyToken != null) {
      await prefs.remove(_kTokenKey);
    }

    User? user;
    final userJson = prefs.getString(_kUserKey);
    if (userJson != null) {
      try {
        user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    return (token: token, user: user);
  }

  static Future<void> saveSession(
    String token,
    Map<String, dynamic> userMap,
  ) async {
    try {
      await _secureStorage.write(key: _kTokenKey, value: token);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.setString(_kUserKey, jsonEncode(userMap));
  }

  static Future<void> saveUserOnly(Map<String, dynamic> userMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(userMap));
  }

  static Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _kTokenKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }
}

