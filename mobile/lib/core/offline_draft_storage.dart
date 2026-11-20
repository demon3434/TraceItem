import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 离线草稿媒体独立沙盒目录管理器（与 MediaCacheManager 物理隔离，不受 LRU 或清空缓存影响）
class OfflineDraftStorage {
  static const String _kDraftRootDir = 'offline_drafts';
  static const _uuid = Uuid();

  static Future<Directory> _userDir(int userId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_kDraftRootDir/u_$userId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> saveBytes(
    int userId,
    String extWithDot,
    Uint8List bytes,
  ) async {
    final dir = await _userDir(userId);
    final name = '${_uuid.v4()}$extWithDot';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String> copyFile(
    int userId,
    String sourcePath,
    String extWithDot,
  ) async {
    final dir = await _userDir(userId);
    final name = '${_uuid.v4()}$extWithDot';
    final target = await File(sourcePath).copy('${dir.path}/$name');
    return target.path;
  }

  static Future<void> deleteFiles(Iterable<String?> paths) async {
    for (final p in paths) {
      if (p == null || p.isEmpty) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}

