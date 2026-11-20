import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'media_cache_manager.dart';
import 'offline_db.dart';
import 'offline_delta_helper.dart';
import 'offline_draft_storage.dart';

/// 移动端离线新建/编辑/删除 Outbox 同步协调器（按 user_id 隔离，串行幂等同步）
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  OfflineSyncService._internal();

  List<OfflineOutboxRecord> _drafts = [];
  bool _isSyncing = false;
  VoidCallback? onSyncedItems;

  List<OfflineOutboxRecord> get drafts => List.unmodifiable(_drafts);
  bool get isSyncing => _isSyncing;

  static String generateClientUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> refreshDrafts() async {
    final userId = ApiService.instance.currentUser?.id;
    if (userId == null) {
      if (_drafts.isNotEmpty) {
        _drafts = [];
        notifyListeners();
      }
      return;
    }
    _drafts = await OfflineDb.instance.getDraftsForUser(userId);
    notifyListeners();
  }

  Future<void> enqueueCreate({
    required int userId,
    required String clientUuid,
    required String itemName,
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final normalizedPayload = Map<String, dynamic>.from(payload)
      ..['client_uuid'] = clientUuid;
    await OfflineDb.instance.insertDraft(
      userId: userId,
      clientUuid: clientUuid,
      itemName: itemName,
      payload: normalizedPayload,
      attachments: attachments,
    );
    await refreshDrafts();
  }

  /// 在线提交或离线入队新建物品；返回 true 表示已入离线队列，false 表示已在线入库
  Future<bool> saveOrQueueCreate({
    required String itemName,
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final userId = ApiService.instance.currentUser?.id;
    final hasOfflineMedia =
        attachments.any((a) => a['is_offline_draft'] == true);
    if (hasOfflineMedia) {
      if (userId == null) throw StateError('未登录，无法保存离线草稿');
      await enqueueCreate(
        userId: userId,
        clientUuid: generateClientUuid(),
        itemName: itemName,
        payload: payload,
        attachments: attachments,
      );
      return true;
    }
    try {
      await ApiService.instance.createItem(payload);
      return false;
    } catch (e) {
      if (ApiService.isNetworkError(e) && userId != null) {
        await enqueueCreate(
          userId: userId,
          clientUuid: generateClientUuid(),
          itemName: itemName,
          payload: payload,
          attachments: attachments,
        );
        return true;
      }
      rethrow;
    }
  }

  /// 在线更新或离线增量入队（计算 changed_fields + 附件增删差集并折叠）
  Future<bool> saveOrQueueUpdate({
    required Item baseline,
    required Map<String, dynamic> fullPayload,
    required List<Map<String, dynamic>> attachments,
    int? expectedVersion,
  }) async {
    final userId = ApiService.instance.currentUser?.id;
    final hasOfflineMedia =
        attachments.any((a) => a['is_offline_draft'] == true);

    Future<void> queuePatch() async {
      if (userId == null) throw StateError('未登录，无法保存离线修改');
      final changed = OfflineDeltaHelper.computeChangedFields(baseline, fullPayload);
      final attDelta = OfflineDeltaHelper.computeAttachmentDelta(baseline, attachments);
      final opUuid = generateClientUuid();
      await OfflineDb.instance.upsertUpdatePatch(
        userId: userId,
        clientOpUuid: opUuid,
        targetItemId: baseline.id,
        baseVersion: expectedVersion ?? baseline.version,
        itemName: (fullPayload['name'] as String?) ?? baseline.name,
        patchPayload: {
          'changed_fields': changed,
          'removed_attachment_paths': attDelta.removedPaths,
        },
        addedAttachments: attDelta.added,
      );
      await refreshDrafts();
    }

    if (hasOfflineMedia) {
      await queuePatch();
      return true;
    }
    final submitPayload = Map<String, dynamic>.from(fullPayload);
    if (expectedVersion != null) {
      submitPayload['expected_version'] = expectedVersion;
    }
    try {
      await ApiService.instance.updateItem(baseline.id, submitPayload);
      return false;
    } catch (e) {
      if (ApiService.isNetworkError(e) && userId != null) {
        await queuePatch();
        return true;
      }
      rethrow;
    }
  }

  /// 在线删除或离线删除入队
  Future<bool> saveOrQueueDelete({required Item item}) async {
    final userId = ApiService.instance.currentUser?.id;
    try {
      await ApiService.instance.deleteItem(item.id);
      if (userId != null) {
        await OfflineDb.instance.removeCachedItem(userId, item.id);
      }
      return false;
    } catch (e) {
      if (ApiService.isNetworkError(e) && userId != null) {
        await OfflineDb.instance.enqueueDeleteOp(
          userId: userId,
          clientOpUuid: generateClientUuid(),
          targetItemId: item.id,
          baseVersion: item.version,
          itemName: item.name,
        );
        await refreshDrafts();
        return true;
      }
      rethrow;
    }
  }

  Future<void> discardDraft(OfflineOutboxRecord record) async {
    final paths = <String?>[];
    for (final att in record.attachments) {
      paths.add(att['local_path'] as String?);
      paths.add(att['local_poster_path'] as String?);
    }
    if (record.opType == 'delete' && record.targetItemId != null) {
      await OfflineDb.instance.markCachedItemPendingDelete(
        record.userId,
        record.targetItemId!,
        false,
      );
    }
    await OfflineDb.instance.deleteDraft(record.id);
    await OfflineDraftStorage.deleteFiles(paths);
    await refreshDrafts();
  }

  /// 冲突仲裁：forceOverwrite=true 强制以本机修改覆盖；false 放弃本机冲突修改
  Future<void> resolveConflict(
    OfflineOutboxRecord record, {
    required bool forceOverwrite,
  }) async {
    if (!forceOverwrite) {
      await discardDraft(record);
      onSyncedItems?.call();
      return;
    }
    if (record.opType == 'delete' && record.targetItemId != null) {
      await ApiService.instance.deleteItem(
        record.targetItemId!,
        expectedVersion: record.baseVersion,
        force: true,
        clientOpUuid: record.clientUuid,
      );
      await OfflineDb.instance.removeCachedItem(record.userId, record.targetItemId!);
      await OfflineDb.instance.deleteDraft(record.id);
    } else if (record.opType == 'update' && record.targetItemId != null) {
      final atts = await _uploadPendingAttachments(record);
      final cleanAdded = atts.map(_stripLocalFields).toList();
      final patchPayload = {
        'expected_version': record.baseVersion,
        'client_op_uuid': record.clientUuid,
        'force_overwrite': true,
        'changed_fields': record.payload['changed_fields'] ?? {},
        'removed_attachment_paths':
            record.payload['removed_attachment_paths'] ?? [],
        if (cleanAdded.isNotEmpty) 'added_attachments': cleanAdded,
      };
      await ApiService.instance.updateItem(record.targetItemId!, patchPayload);
      await _cleanupRecordFilesAndRow(record, atts);
    }
    await refreshDrafts();
    onSyncedItems?.call();
  }

  /// 串行同步当前登录用户的离线草稿，返回成功入库/合并数量
  Future<int> syncCurrentUser({bool includeFailed = false}) async {
    if (_isSyncing) return 0;
    final user = ApiService.instance.currentUser;
    final token = ApiService.instance.token;
    if (user == null || token == null || token.isEmpty) return 0;

    _isSyncing = true;
    notifyListeners();
    var syncedCount = 0;

    try {
      final records = await OfflineDb.instance.getDraftsForUser(user.id);
      final queue = includeFailed
          ? records.where((r) => r.status != 'conflict').toList()
          : records
              .where((r) => r.status != 'failed' && r.status != 'conflict')
              .toList();

      for (final record in queue) {
        if (ApiService.instance.currentUser?.id != user.id) break;
        await OfflineDb.instance.updateStatus(record.id, 'uploading');
        try {
          await _syncSingleRecord(record);
          syncedCount++;
        } catch (e) {
          if (ApiService.isNetworkError(e)) {
            await OfflineDb.instance.updateStatus(
              record.id,
              'pending',
              errorMsg: '网络不可用，等待恢复后自动同步',
            );
            break;
          }
          if (ApiService.isConflictError(e)) {
            await OfflineDb.instance.updateStatus(
              record.id,
              'conflict',
              errorMsg: ApiService.formatDioError(e),
              conflictData: ApiService.extractConflictData(e),
            );
          } else {
            await OfflineDb.instance.updateStatus(
              record.id,
              'failed',
              errorMsg: ApiService.formatDioError(e),
            );
          }
        }
      }
    } finally {
      _isSyncing = false;
      await refreshDrafts();
      if (syncedCount > 0) {
        onSyncedItems?.call();
      }
    }

    return syncedCount;
  }

  Future<void> _syncSingleRecord(OfflineOutboxRecord record) async {
    if (record.opType == 'delete' && record.targetItemId != null) {
      try {
        await ApiService.instance.deleteItem(
          record.targetItemId!,
          expectedVersion: record.baseVersion,
          clientOpUuid: record.clientUuid,
        );
      } catch (e) {
        if (!ApiService.isNotFoundError(e)) rethrow;
      }
      await OfflineDb.instance.removeCachedItem(record.userId, record.targetItemId!);
      await OfflineDb.instance.deleteDraft(record.id);
      return;
    }

    final atts = await _uploadPendingAttachments(record);
    if (record.opType == 'update' && record.targetItemId != null) {
      final cleanAdded = atts.map(_stripLocalFields).toList();
      final patchPayload = {
        'expected_version': record.baseVersion,
        'client_op_uuid': record.clientUuid,
        'changed_fields': record.payload['changed_fields'] ?? {},
        'removed_attachment_paths':
            record.payload['removed_attachment_paths'] ?? [],
        if (cleanAdded.isNotEmpty) 'added_attachments': cleanAdded,
      };
      await ApiService.instance.updateItem(record.targetItemId!, patchPayload);
      await _cleanupRecordFilesAndRow(record, atts);
      return;
    }

    final submitPayload = Map<String, dynamic>.from(record.payload)
      ..['client_uuid'] = record.clientUuid
      ..['attachments'] = atts.map(_stripLocalFields).toList();
    await ApiService.instance.createItem(submitPayload);
    await _cleanupRecordFilesAndRow(record, atts);
  }

  Future<List<Map<String, dynamic>>> _uploadPendingAttachments(
    OfflineOutboxRecord record,
  ) async {
    final atts = record.attachments.map((e) => Map<String, dynamic>.from(e)).toList();
    for (var i = 0; i < atts.length; i++) {
      final att = atts[i];
      final hasRemote = (att['file_path'] as String?)?.isNotEmpty == true;
      if (att['is_offline_draft'] != true || hasRemote) continue;
      final uploaded = await _uploadDraftAttachment(att);
      atts[i] = {...att, ...uploaded}..remove('is_offline_draft');
      await OfflineDb.instance.updateAttachments(record.id, atts);
    }
    return atts;
  }

  Map<String, dynamic> _stripLocalFields(Map<String, dynamic> a) {
    final copy = Map<String, dynamic>.from(a);
    copy.remove('local_path');
    copy.remove('local_poster_path');
    copy.remove('is_offline_draft');
    return copy;
  }

  Future<void> _cleanupRecordFilesAndRow(
    OfflineOutboxRecord record,
    List<Map<String, dynamic>> atts,
  ) async {
    await OfflineDb.instance.deleteDraft(record.id);
    final pathsToDelete = <String?>[];
    for (final a in atts) {
      pathsToDelete.add(a['local_path'] as String?);
      pathsToDelete.add(a['local_poster_path'] as String?);
    }
    await OfflineDraftStorage.deleteFiles(pathsToDelete);
  }

  Future<Map<String, dynamic>> _uploadDraftAttachment(
    Map<String, dynamic> att,
  ) async {
    final localPath = att['local_path'] as String?;
    final mediaType = att['media_type'] as String? ?? 'image';
    if (localPath == null || localPath.isEmpty) {
      throw StateError('草稿媒体路径缺失');
    }
    final file = File(localPath);
    if (!file.existsSync()) {
      throw StateError('本地草稿媒体文件已丢失');
    }

    final filename = localPath.split('/').last.split('\\').last;
    if (mediaType == 'image') {
      final bytes = await file.readAsBytes();
      final res = await ApiService.instance.uploadImageBytes(bytes, filename);
      final remotePath = res['file_path'] as String?;
      if (remotePath != null && remotePath.isNotEmpty) {
        await MediaCacheManager.instance.putFile(remotePath, file);
      }
      return res;
    }

    if (mediaType == 'video') {
      final localPoster = att['local_poster_path'] as String?;
      final dur = (att['duration_seconds'] as num?)?.toInt() ?? 0;
      final res = await ApiService.instance.uploadVideoFile(
        localPath,
        filename,
        dur,
        posterPath: localPoster,
      );
      final remotePath = res['file_path'] as String?;
      if (remotePath != null && remotePath.isNotEmpty) {
        await MediaCacheManager.instance.putFile(remotePath, file);
      }
      final thumbPath = res['thumbnail_path'] as String?;
      if (localPoster != null &&
          localPoster.isNotEmpty &&
          thumbPath != null &&
          thumbPath.isNotEmpty) {
        final posterFile = File(localPoster);
        if (posterFile.existsSync()) {
          await MediaCacheManager.instance.putFile(thumbPath, posterFile);
        }
      }
      return res;
    }

    final bytes = await file.readAsBytes();
    final dur = (att['duration_seconds'] as num?)?.toInt() ?? 0;
    final res = await ApiService.instance.uploadAudioBytes(bytes, filename, dur);
    final remotePath = res['file_path'] as String?;
    if (remotePath != null && remotePath.isNotEmpty) {
      await MediaCacheManager.instance.putFile(remotePath, file);
    }
    return res;
  }
}
