import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'media_cache_manager.dart';
import 'meta_snapshot_store.dart';
import 'offline_db.dart';

/// 跨服务器/重部署环境实例指纹卫士
/// 当探测到服务端 server_instance_id 发生变动（换服务器IP或全新建库重部署），
/// 自动彻底抹除旧客户端离线数据库、元数据快照与图片缓存，防止历史幽灵脏数据残留。
class ServerIdentityGuard {
  static final ServerIdentityGuard instance = ServerIdentityGuard._internal();
  ServerIdentityGuard._internal();

  static const String _kKey = 'traceitem_last_server_instance_id';

  Future<String?> getLastServerInstanceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKey);
  }

  /// 检查新实例指纹，若检测到服务器迁移或重新建库，执行全自动缓存自愈与重置序列
  /// 返回 true 表示检测到变动并已执行重置序列
  Future<bool> checkAndHandleInstanceChange(String? newInstanceId) async {
    if (newInstanceId == null || newInstanceId.trim().isEmpty) {
      return false;
    }
    final cleanId = newInstanceId.trim();
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_kKey);

    if (lastId != null && lastId.isNotEmpty && lastId != cleanId) {
      debugPrint(
        '[ServerIdentityGuard] ⚠️ 检测到服务端指纹变动 ($lastId -> $cleanId)，启动自动自愈重置序列...',
      );

      // 1. 抹除本地离线数据库 (包括待同步 outbox 与历史物品缓存)
      await OfflineDb.instance.clearAllCache();

      // 2. 抹除所有用户的房间/分类元数据快照
      await MetaSnapshotStore.clearAllSnapshots();

      // 3. 清空多媒体磁盘缓存
      await MediaCacheManager.instance.clearAllCache();

      // 4. 注销当前本地旧会话，防止过期 token 引发 401
      await ApiService.instance.logout();

      // 5. 记录更新后的实例指纹
      await prefs.setString(_kKey, cleanId);

      debugPrint('[ServerIdentityGuard] ✓ 本地脏缓存与旧会话已彻底抹除，环境已恢复纯净状态。');
      return true;
    }

    // 首次连入或指纹一致
    if (lastId != cleanId) {
      await prefs.setString(_kKey, cleanId);
    }
    return false;
  }

  /// 手动重置持久化指纹（主要供测试或调试使用）
  Future<void> clearInstanceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

