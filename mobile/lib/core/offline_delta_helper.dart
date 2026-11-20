import '../models/models.dart';

/// 离线编辑增量计算与 Outbox 折叠辅助工具
class OfflineDeltaHelper {
  /// 计算标量/标签字段相对基线快照的增量变更集
  static Map<String, dynamic> computeChangedFields(
    Item baseline,
    Map<String, dynamic> formPayload,
  ) {
    final changed = <String, dynamic>{};

    void check(String key, dynamic baselineVal, dynamic currentVal) {
      if (baselineVal != currentVal) {
        changed[key] = currentVal;
      }
    }

    check('house_id', baseline.houseId, formPayload['house_id']);
    check('room_id', baseline.roomId, formPayload['room_id']);
    check('category_id', baseline.categoryId, formPayload['category_id']);
    check('name', baseline.name, formPayload['name']);
    check('brand', baseline.brand, formPayload['brand']);
    check('quantity', baseline.quantity, formPayload['quantity']);
    check('location_detail', baseline.locationDetail, formPayload['location_detail']);
    check('description', baseline.description, formPayload['description']);

    final baseTags = baseline.tags.map((t) => t.name).toList();
    final curTags = (formPayload['tag_names'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    if (!_listEquals(baseTags, curTags)) {
      changed['tag_names'] = curTags;
    }

    return changed;
  }

  /// 计算附件列表相对基线快照的增量新增与删除
  static ({
    List<Map<String, dynamic>> added,
    List<String> removedPaths,
  }) computeAttachmentDelta(
    Item baseline,
    List<Map<String, dynamic>> currentAttachments,
  ) {
    final basePaths = baseline.attachments.map((a) => a.filePath).toSet();
    final curRemotePaths = currentAttachments
        .where((a) => a['is_offline_draft'] != true)
        .map((a) => a['file_path'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();

    final removedPaths = basePaths.difference(curRemotePaths).toList();
    final added = currentAttachments.where((a) {
      if (a['is_offline_draft'] == true) return true;
      final fp = a['file_path'] as String? ?? '';
      return fp.isNotEmpty && !basePaths.contains(fp);
    }).map((a) => Map<String, dynamic>.from(a)).toList();

    return (added: added, removedPaths: removedPaths);
  }

  /// 将新的 update 增量合并折叠进已有的 update payload 中
  static Map<String, dynamic> mergeUpdatePayloads(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final mergedChanged = Map<String, dynamic>.from(
      existing['changed_fields'] as Map? ?? {},
    )..addAll(
        Map<String, dynamic>.from(incoming['changed_fields'] as Map? ?? {}),
      );

    final mergedRemoved = <String>{
      ...(existing['removed_attachment_paths'] as List<dynamic>? ?? [])
          .map((e) => e.toString()),
      ...(incoming['removed_attachment_paths'] as List<dynamic>? ?? [])
          .map((e) => e.toString()),
    }.toList();

    return {
      ...existing,
      'changed_fields': mergedChanged,
      'removed_attachment_paths': mergedRemoved,
    };
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

