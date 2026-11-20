import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 房屋/房间/分类本地元数据快照（按 user_id 隔离，供离线录入回退读取）
class MetaSnapshotStore {
  static const String _kPrefix = 'traceitem_meta_snapshot_u_';

  static Future<void> saveSnapshot({
    required int userId,
    required List<House> houses,
    required List<Room> rooms,
    required List<Category> categories,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'houses': houses.map((e) => e.toJson()).toList(),
      'rooms': rooms.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString('$_kPrefix$userId', jsonEncode(payload));
  }

  static Future<({
    List<House> houses,
    List<Room> rooms,
    List<Category> categories,
  })?> loadSnapshot(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$userId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final houses = (map['houses'] as List<dynamic>? ?? [])
          .map((e) => House.fromJson(e as Map<String, dynamic>))
          .toList();
      final rooms = (map['rooms'] as List<dynamic>? ?? [])
          .map((e) => Room.fromJson(e as Map<String, dynamic>))
          .toList();
      final categories = (map['categories'] as List<dynamic>? ?? [])
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      return (houses: houses, rooms: rooms, categories: categories);
    } catch (_) {
      return null;
    }
  }
}

