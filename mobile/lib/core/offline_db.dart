import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'offline_delta_helper.dart';

class OfflineOutboxRecord {
  final int id;
  final int userId;
  final String clientUuid;
  final String opType; // create | update | delete
  final int? targetItemId;
  final int? baseVersion;
  final String itemName;
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> attachments;
  final String status; // pending | uploading | failed | conflict
  final String? errorMsg;
  final Map<String, dynamic>? conflictData;
  final int createdAt;

  OfflineOutboxRecord({
    required this.id,
    required this.userId,
    required this.clientUuid,
    required this.opType,
    this.targetItemId,
    this.baseVersion,
    required this.itemName,
    required this.payload,
    required this.attachments,
    required this.status,
    this.errorMsg,
    this.conflictData,
    required this.createdAt,
  });

  factory OfflineOutboxRecord.fromRow(Map<String, dynamic> row) {
    final decodedPayload =
        jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
    final decodedAtts = (jsonDecode(row['attachments_json'] as String)
            as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final rawConflict = row['conflict_json'] as String?;
    return OfflineOutboxRecord(
      id: (row['id'] as num).toInt(),
      userId: (row['user_id'] as num).toInt(),
      clientUuid: row['client_uuid'] as String,
      opType: row['op_type'] as String? ?? 'create',
      targetItemId: (row['target_item_id'] as num?)?.toInt(),
      baseVersion: (row['base_version'] as num?)?.toInt(),
      itemName: row['item_name'] as String,
      payload: decodedPayload,
      attachments: decodedAtts,
      status: row['status'] as String? ?? 'pending',
      errorMsg: row['error_msg'] as String?,
      conflictData: rawConflict != null && rawConflict.isNotEmpty
          ? jsonDecode(rawConflict) as Map<String, dynamic>
          : null,
      createdAt: (row['created_at'] as num).toInt(),
    );
  }
}

/// 离线新建/编辑/删除 Outbox 与存量物品本地只读缓存（按 user_id 严格隔离）
class OfflineDb {
  static final OfflineDb instance = OfflineDb._internal();
  OfflineDb._internal();

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final dbPath = '$dbDir/traceitem_offline.db';
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE offline_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            client_uuid TEXT NOT NULL UNIQUE,
            op_type TEXT NOT NULL DEFAULT 'create',
            target_item_id INTEGER,
            base_version INTEGER,
            item_name TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            attachments_json TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            error_msg TEXT,
            conflict_json TEXT,
            created_at INTEGER NOT NULL
          );
        ''');
        await db.execute(
          'CREATE INDEX ix_outbox_user ON offline_outbox(user_id, created_at);',
        );
        await _createCachedItemsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final cols = (await db.rawQuery('PRAGMA table_info(offline_outbox);'))
              .map((r) => r['name'] as String)
              .toSet();
          if (!cols.contains('op_type')) {
            await db.execute(
              "ALTER TABLE offline_outbox ADD COLUMN op_type TEXT NOT NULL DEFAULT 'create';",
            );
          }
          if (!cols.contains('target_item_id')) {
            await db.execute(
              'ALTER TABLE offline_outbox ADD COLUMN target_item_id INTEGER;',
            );
          }
          if (!cols.contains('base_version')) {
            await db.execute(
              'ALTER TABLE offline_outbox ADD COLUMN base_version INTEGER;',
            );
          }
          if (!cols.contains('conflict_json')) {
            await db.execute(
              'ALTER TABLE offline_outbox ADD COLUMN conflict_json TEXT;',
            );
          }
          await _createCachedItemsTable(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createCachedItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_items (
        user_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        house_id INTEGER NOT NULL,
        room_id INTEGER NOT NULL,
        category_id INTEGER,
        item_json TEXT NOT NULL,
        pending_delete INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, item_id)
      );
    ''');
  }

  Future<int> insertDraft({
    required int userId,
    required String clientUuid,
    String opType = 'create',
    int? targetItemId,
    int? baseVersion,
    required String itemName,
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final db = await _getDb();
    return db.insert(
      'offline_outbox',
      {
        'user_id': userId,
        'client_uuid': clientUuid,
        'op_type': opType,
        'target_item_id': targetItemId,
        'base_version': baseVersion,
        'item_name': itemName,
        'payload_json': jsonEncode(payload),
        'attachments_json': jsonEncode(attachments),
        'status': 'pending',
        'error_msg': null,
        'conflict_json': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 存量物品离线编辑折叠入队：若已有同物品 update 则合并 changed_fields 并保留初始 base_version
  Future<void> upsertUpdatePatch({
    required int userId,
    required String clientOpUuid,
    required int targetItemId,
    required int baseVersion,
    required String itemName,
    required Map<String, dynamic> patchPayload,
    required List<Map<String, dynamic>> addedAttachments,
  }) async {
    final db = await _getDb();
    final existing = await db.query(
      'offline_outbox',
      where: 'user_id = ? AND target_item_id = ? AND op_type = ?',
      whereArgs: [userId, targetItemId, 'update'],
      limit: 1,
    );
    if (existing.isEmpty) {
      await insertDraft(
        userId: userId,
        clientUuid: clientOpUuid,
        opType: 'update',
        targetItemId: targetItemId,
        baseVersion: baseVersion,
        itemName: itemName,
        payload: patchPayload,
        attachments: addedAttachments,
      );
      return;
    }

    final rec = OfflineOutboxRecord.fromRow(existing.first);
    final mergedPayload = OfflineDeltaHelper.mergeUpdatePayloads(
      rec.payload,
      patchPayload,
    );
    final mergedAdded = [...rec.attachments, ...addedAttachments];
    await db.update(
      'offline_outbox',
      {
        'client_uuid': clientOpUuid,
        'item_name': itemName,
        'payload_json': jsonEncode(mergedPayload),
        'attachments_json': jsonEncode(mergedAdded),
        'status': 'pending',
        'error_msg': null,
        'conflict_json': null,
      },
      where: 'id = ?',
      whereArgs: [rec.id],
    );
  }

  /// 存量物品离线删除入队：自动清理同物品未同步的 update 草稿，并标记本地缓存隐藏
  Future<void> enqueueDeleteOp({
    required int userId,
    required String clientOpUuid,
    required int targetItemId,
    required int baseVersion,
    required String itemName,
  }) async {
    final db = await _getDb();
    await db.delete(
      'offline_outbox',
      where: 'user_id = ? AND target_item_id = ? AND op_type = ?',
      whereArgs: [userId, targetItemId, 'update'],
    );
    await insertDraft(
      userId: userId,
      clientUuid: clientOpUuid,
      opType: 'delete',
      targetItemId: targetItemId,
      baseVersion: baseVersion,
      itemName: itemName,
      payload: {'expected_version': baseVersion, 'client_op_uuid': clientOpUuid},
      attachments: const [],
    );
    await markCachedItemPendingDelete(userId, targetItemId, true);
  }

  Future<List<OfflineOutboxRecord>> getDraftsForUser(int userId) async {
    final db = await _getDb();
    final rows = await db.query(
      'offline_outbox',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(OfflineOutboxRecord.fromRow).toList();
  }

  Future<void> updateStatus(
    int id,
    String status, {
    String? errorMsg,
    Map<String, dynamic>? conflictData,
  }) async {
    final db = await _getDb();
    await db.update(
      'offline_outbox',
      {
        'status': status,
        'error_msg': errorMsg,
        'conflict_json': conflictData != null ? jsonEncode(conflictData) : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAttachments(
    int id,
    List<Map<String, dynamic>> attachments,
  ) async {
    final db = await _getDb();
    await db.update(
      'offline_outbox',
      {'attachments_json': jsonEncode(attachments)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDraft(int id) async {
    final db = await _getDb();
    await db.delete('offline_outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertCachedItems(int userId, List<Item> items) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pendingDeleteRows = await db.query(
      'offline_outbox',
      columns: ['target_item_id'],
      where: 'user_id = ? AND op_type = ? AND target_item_id IS NOT NULL',
      whereArgs: [userId, 'delete'],
    );
    final pendingDeletes = pendingDeleteRows
        .map((r) => (r['target_item_id'] as num).toInt())
        .toSet();

    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'cached_items',
        {
          'user_id': userId,
          'item_id': item.id,
          'house_id': item.houseId,
          'room_id': item.roomId,
          'category_id': item.categoryId,
          'item_json': jsonEncode(item.toJson()),
          'pending_delete': pendingDeletes.contains(item.id) ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Item>> getCachedItems(
    int userId, {
    int? houseId,
    int? roomId,
    int? categoryId,
    String? query,
  }) async {
    final db = await _getDb();
    final whereParts = <String>['user_id = ?', 'pending_delete = 0'];
    final args = <Object?>[userId];
    if (houseId != null) {
      whereParts.add('house_id = ?');
      args.add(houseId);
    }
    if (roomId != null) {
      whereParts.add('room_id = ?');
      args.add(roomId);
    }
    if (categoryId != null) {
      whereParts.add('category_id = ?');
      args.add(categoryId);
    }
    final rows = await db.query(
      'cached_items',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC, item_id DESC',
    );
    var items = rows
        .map((r) => Item.fromJson(
            jsonDecode(r['item_json'] as String) as Map<String, dynamic>))
        .toList();
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isNotEmpty) {
      final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      items = items.where((it) {
        final tagNames = it.tags.map((t) => t.name).join(' ');
        final haystack =
            '${it.name} ${it.brand} ${it.locationDetail} ${it.description} '
                    '${it.house?.name ?? ''} ${it.room?.name ?? ''} '
                    '${it.category?.name ?? ''} $tagNames'
                .toLowerCase();
        return terms.every((t) => haystack.contains(t));
      }).toList();
    }
    return items;
  }

  Future<void> markCachedItemPendingDelete(
    int userId,
    int itemId,
    bool pendingDelete,
  ) async {
    final db = await _getDb();
    await db.update(
      'cached_items',
      {'pending_delete': pendingDelete ? 1 : 0},
      where: 'user_id = ? AND item_id = ?',
      whereArgs: [userId, itemId],
    );
  }

  Future<void> removeCachedItem(int userId, int itemId) async {
    final db = await _getDb();
    await db.delete(
      'cached_items',
      where: 'user_id = ? AND item_id = ?',
      whereArgs: [userId, itemId],
    );
  }

  Future<void> clearAllCache() async {
    final db = await _getDb();
    await db.delete('cached_items');
    await db.delete('offline_outbox');
  }

  Future<void> clearUserCache(int userId) async {
    final db = await _getDb();
    await db.delete(
      'cached_items',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearScopeCache(
    int userId, {
    int? houseId,
    int? roomId,
    int? categoryId,
  }) async {
    final db = await _getDb();
    final whereParts = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (houseId != null) {
      whereParts.add('house_id = ?');
      args.add(houseId);
    }
    if (roomId != null) {
      whereParts.add('room_id = ?');
      args.add(roomId);
    }
    if (categoryId != null) {
      whereParts.add('category_id = ?');
      args.add(categoryId);
    }
    await db.delete(
      'cached_items',
      where: whereParts.join(' AND '),
      whereArgs: args,
    );
  }
}
