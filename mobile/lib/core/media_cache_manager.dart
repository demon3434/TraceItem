import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class CacheEntry {
  final String key;
  final String localPath;
  final int fileSize;
  int lastAccessed;

  CacheEntry({
    required this.key,
    required this.localPath,
    required this.fileSize,
    required this.lastAccessed,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'localPath': localPath,
        'fileSize': fileSize,
        'lastAccessed': lastAccessed,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        key: json['key'] as String,
        localPath: json['localPath'] as String,
        fileSize: (json['fileSize'] as num).toInt(),
        lastAccessed: (json['lastAccessed'] as num).toInt(),
      );
}

/// 移动端多媒体持久化磁盘缓存池与 LRU 管理器（按 user_id 分桶隔离 + 设备级共享配额）
class MediaCacheManager {
  static final MediaCacheManager instance = MediaCacheManager._internal();
  MediaCacheManager._internal();

  static const String _kLegacyIndexPrefKey = 'traceitem_media_cache_index';
  static const String _kIndexPrefix = 'traceitem_media_cache_index_u_';
  static const String _kQuotaPrefKey = 'traceitem_media_cache_quota_mb';
  static const String _kCacheRootDir = 'traceitem_media_cache';

  Directory? _rootCacheDir;
  Directory? _userCacheDir;
  int? _activeUserId;
  final Map<String, CacheEntry> _index = {};
  bool _initialized = false;
  bool _legacyCleaned = false;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  String _indexKeyFor(int userId) => '$_kIndexPrefix$userId';

  String _normalizeKey(String keyOrUrl) {
    if (keyOrUrl.isEmpty) return 'empty';
    try {
      final uri = Uri.parse(keyOrUrl);
      if (uri.hasScheme) return uri.path;
    } catch (_) {}
    return keyOrUrl.split('?').first;
  }

  String _generateFileName(String normalizedKey) {
    final bytes = utf8.encode(normalizedKey);
    var hash = 0xcbf29ce484222325;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(16, '0');
    String ext = '.bin';
    final dotIdx = normalizedKey.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < normalizedKey.length - 1) {
      final cand = normalizedKey.substring(dotIdx);
      if (cand.length <= 6 && !cand.contains('/')) ext = cand;
    }
    return '${hex}_${bytes.length}$ext';
  }

  Future<void> switchUser(int? userId) async {
    if (_activeUserId == userId && _initialized) return;
    _activeUserId = userId;
    _initialized = false;
    _index.clear();
    _userCacheDir = null;
    if (userId != null) {
      await init();
    }
  }

  Future<void> _cleanupLegacyFlatCache(SharedPreferences prefs) async {
    if (_legacyCleaned || _rootCacheDir == null) return;
    _legacyCleaned = true;
    try {
      if (prefs.containsKey(_kLegacyIndexPrefKey)) {
        await prefs.remove(_kLegacyIndexPrefKey);
      }
      if (await _rootCacheDir!.exists()) {
        await for (final entity in _rootCacheDir!.list()) {
          final name = entity.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .lastOrNull;
          if (entity is File || (name != null && !name.startsWith('u_'))) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final baseDir = await getApplicationSupportDirectory();
      _rootCacheDir = Directory('${baseDir.path}/$_kCacheRootDir');
      if (!await _rootCacheDir!.exists()) {
        await _rootCacheDir!.create(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await _cleanupLegacyFlatCache(prefs);

      if (_activeUserId == null) {
        _initialized = true;
        return;
      }

      _userCacheDir = Directory('${_rootCacheDir!.path}/u_$_activeUserId');
      if (!await _userCacheDir!.exists()) {
        await _userCacheDir!.create(recursive: true);
      }

      _index.clear();
      final rawIndex = prefs.getString(_indexKeyFor(_activeUserId!));
      if (rawIndex != null && rawIndex.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawIndex);
        for (final entry in decoded.entries) {
          try {
            final item =
                CacheEntry.fromJson(entry.value as Map<String, dynamic>);
            if (File(item.localPath).existsSync()) {
              _index[entry.key] = item;
            }
          } catch (_) {}
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[MediaCacheManager] init error: $e');
    }
  }

  Future<void> _saveIndex() async {
    if (_activeUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _index.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_indexKeyFor(_activeUserId!), jsonEncode(map));
    } catch (e) {
      debugPrint('[MediaCacheManager] saveIndex error: $e');
    }
  }

  Future<File?> get(String keyOrUrl) async {
    await init();
    if (_activeUserId == null) return null;
    final normKey = _normalizeKey(keyOrUrl);
    final entry = _index[normKey];
    if (entry == null) return null;

    final file = File(entry.localPath);
    if (!file.existsSync()) {
      _index.remove(normKey);
      await _saveIndex();
      return null;
    }

    entry.lastAccessed = DateTime.now().millisecondsSinceEpoch;
    _saveIndex();
    return file;
  }

  Future<File?> putFile(String keyOrUrl, File sourceFile) async {
    await init();
    if (_userCacheDir == null || !sourceFile.existsSync()) return null;

    try {
      final normKey = _normalizeKey(keyOrUrl);
      final fileName = _generateFileName(normKey);
      final targetPath = '${_userCacheDir!.path}/$fileName';
      final targetFile = File(targetPath);

      if (sourceFile.path != targetFile.path) {
        await sourceFile.copy(targetPath);
      }

      final fileSize = await targetFile.length();
      _index[normKey] = CacheEntry(
        key: normKey,
        localPath: targetPath,
        fileSize: fileSize,
        lastAccessed: DateTime.now().millisecondsSinceEpoch,
      );
      await _saveIndex();
      await _checkAndEvictQuota();
      return targetFile;
    } catch (e) {
      debugPrint('[MediaCacheManager] putFile error: $e');
      return null;
    }
  }

  Future<File?> downloadAndCache(
    String keyOrUrl,
    String remoteUrl, {
    Map<String, String>? headers,
  }) async {
    await init();
    if (_userCacheDir == null) return null;

    final normKey = _normalizeKey(keyOrUrl);
    final fileName = _generateFileName(normKey);
    final tempPath = '${_userCacheDir!.path}/tmp_$fileName';
    final targetPath = '${_userCacheDir!.path}/$fileName';

    try {
      final response = await _dio.download(
        remoteUrl,
        tempPath,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          final targetFile = await tempFile.rename(targetPath);
          final fileSize = await targetFile.length();
          _index[normKey] = CacheEntry(
            key: normKey,
            localPath: targetPath,
            fileSize: fileSize,
            lastAccessed: DateTime.now().millisecondsSinceEpoch,
          );
          await _saveIndex();
          await _checkAndEvictQuota();
          return targetFile;
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheManager] download error for $remoteUrl: $e');
      final tempFile = File(tempPath);
      if (tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
    return null;
  }

  Future<int> getCurrentCacheSizeBytes() async {
    await init();
    int total = 0;
    for (final entry in _index.values) {
      total += entry.fileSize;
    }
    return total;
  }

  Future<int> getTotalDeviceCacheSizeBytes() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kIndexPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final val in decoded.values) {
          total += ((val as Map<String, dynamic>)['fileSize'] as num).toInt();
        }
      } catch (_) {}
    }
    return total;
  }

  Future<int> getCacheQuotaMb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kQuotaPrefKey) ??
        AppConstants.mediaCacheDefaultMaxMb;
  }

  Future<void> setCacheQuotaMb(int mb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuotaPrefKey, mb);
    await _checkAndEvictQuota();
  }

  /// 设备级全局 LRU 淘汰：跨分桶统计总容量，超限时清理至 80% 安全水位线
  Future<void> _checkAndEvictQuota() async {
    final quotaMb = await getCacheQuotaMb();
    final maxBytes = quotaMb * 1024 * 1024;
    final prefs = await SharedPreferences.getInstance();

    final bucketMaps = <String, Map<String, CacheEntry>>{};
    final allRecords = <({String prefKey, CacheEntry entry})>[];
    int totalBytes = 0;

    for (final prefKey in prefs.getKeys()) {
      if (!prefKey.startsWith(_kIndexPrefix)) continue;
      final raw = prefs.getString(prefKey);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final bucket = <String, CacheEntry>{};
        for (final kv in decoded.entries) {
          final entry = CacheEntry.fromJson(kv.value as Map<String, dynamic>);
          bucket[kv.key] = entry;
          totalBytes += entry.fileSize;
          allRecords.add((prefKey: prefKey, entry: entry));
        }
        bucketMaps[prefKey] = bucket;
      } catch (_) {}
    }

    if (totalBytes <= maxBytes) return;

    final targetBytes = (maxBytes * 0.8).round();
    allRecords.sort(
      (a, b) => a.entry.lastAccessed.compareTo(b.entry.lastAccessed),
    );
    final dirtyBuckets = <String>{};

    for (final rec in allRecords) {
      if (totalBytes <= targetBytes) break;
      try {
        final file = File(rec.entry.localPath);
        if (file.existsSync()) await file.delete();
        totalBytes -= rec.entry.fileSize;
        bucketMaps[rec.prefKey]?.remove(rec.entry.key);
        dirtyBuckets.add(rec.prefKey);
        if (_activeUserId != null &&
            rec.prefKey == _indexKeyFor(_activeUserId!)) {
          _index.remove(rec.entry.key);
        }
      } catch (_) {}
    }

    for (final prefKey in dirtyBuckets) {
      final bucket = bucketMaps[prefKey] ?? {};
      final serialized = bucket.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(prefKey, jsonEncode(serialized));
    }
  }

  /// 仅清空当前登录账号的缓存分桶目录与索引
  Future<void> clearAllCache() async {
    await init();
    try {
      if (_userCacheDir != null && await _userCacheDir!.exists()) {
        await _userCacheDir!.delete(recursive: true);
        await _userCacheDir!.create(recursive: true);
      }
      _index.clear();
      if (_activeUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_indexKeyFor(_activeUserId!));
      }
    } catch (e) {
      debugPrint('[MediaCacheManager] clearAllCache error: $e');
    }
  }
}
