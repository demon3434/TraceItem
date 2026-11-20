import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/offline_db.dart';
import '../core/offline_sync_service.dart';
import 'custom_dialogs.dart';

/// 待同步离线草稿管理与并发冲突仲裁半屏抽屉
class OfflineOutboxSheet {
  static Future<void> show(BuildContext context) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: OfflineSyncService.instance,
          builder: (sheetCtx, _) {
            final drafts = OfflineSyncService.instance.drafts;
            final syncing = OfflineSyncService.instance.isSyncing;

            return ShadSheet(
              radius: const BorderRadius.vertical(top: Radius.circular(24)),
              scrollPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              title: const Text(
                '待同步离线草稿',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              description: Text(
                drafts.isEmpty
                    ? '所有草稿已同步完成'
                    : '共 ${drafts.length} 条记录等待上传，支持手动重试或放弃草稿',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              actionsAxis: Axis.horizontal,
              expandActionsWhenTiny: false,
              actionsPinned: false,
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('关闭', style: TextStyle(fontSize: 14)),
                ),
                if (drafts.isNotEmpty)
                  ShadButton(
                    onPressed: syncing
                        ? null
                        : () async {
                            final count = await OfflineSyncService.instance
                                .syncCurrentUser(includeFailed: true);
                            if (!sheetCtx.mounted) return;
                            if (count > 0) {
                              CustomDialogs.showToast(
                                sheetCtx,
                                '成功同步 $count 件物品',
                              );
                            }
                          },
                    child: Text(
                      syncing ? '同步中...' : '全部重试',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
              child: drafts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '暂无待同步草稿',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: drafts
                          .map((d) => _DraftTile(record: d))
                          .toList(),
                    ),
            );
          },
        );
      },
    );
  }
}

class _DraftTile extends StatelessWidget {
  final OfflineOutboxRecord record;

  const _DraftTile({required this.record});

  String _opLabel() {
    switch (record.opType) {
      case 'update':
        return '离线编辑';
      case 'delete':
        return '离线删除';
      default:
        return '离线新建';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConflict = record.status == 'conflict';
    final isFailed = record.status == 'failed';
    final isUploading = record.status == 'uploading';
    final isAlert = isConflict || isFailed;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isConflict ? () => _showConflictSheet(context, record) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${_opLabel()}] ${record.itemName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isUploading
                        ? '正在同步至云端...'
                        : (record.errorMsg?.isNotEmpty == true
                            ? record.errorMsg!
                            : '等待网络同步 (${record.attachments.length} 个附件)'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isAlert
                          ? const Color(0xFFE11D48)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isConflict)
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => _showConflictSheet(context, record),
                child: const Text('处理冲突', style: TextStyle(fontSize: 12)),
              )
            else
              IconButton(
                tooltip: '草稿操作',
                icon: const Icon(LucideIcons.ellipsis, size: 18),
                onPressed: isUploading
                    ? null
                    : () async {
                        final confirmed = await CustomDialogs.showConfirm(
                          context: context,
                          title: '放弃离线草稿',
                          message:
                              '确定放弃「${record.itemName}」的离线操作吗？此操作不可撤销。',
                          confirmText: '放弃草稿',
                          isDanger: true,
                        );
                        if (confirmed) {
                          await OfflineSyncService.instance.discardDraft(record);
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  void _showConflictSheet(BuildContext context, OfflineOutboxRecord rec) {
    final conflictFields =
        (rec.conflictData?['conflict_fields'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .join(', ');
    final latest = rec.conflictData?['latest_item'] as Map<String, dynamic>?;
    final localChanged = rec.payload['changed_fields'] as Map<String, dynamic>?;

    CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        scrollPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        title: const Text(
          '并发修改冲突仲裁',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        description: Text(
          rec.opType == 'delete'
              ? '「${rec.itemName}」在离线期间已被他人更新，请选择处理方式'
              : '字段 [$conflictFields] 与云端最新版存在并发冲突',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        actionsAxis: Axis.horizontal,
        expandActionsWhenTiny: false,
        actionsPinned: false,
        actions: [
          ShadButton.outline(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await OfflineSyncService.instance
                  .resolveConflict(rec, forceOverwrite: false);
              if (context.mounted) {
                CustomDialogs.showToast(context, '已采用云端最新并放弃本机冲突修改');
              }
            },
            child: const Text('采用云端最新', style: TextStyle(fontSize: 14)),
          ),
          ShadButton.destructive(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await OfflineSyncService.instance
                  .resolveConflict(rec, forceOverwrite: true);
              if (context.mounted) {
                CustomDialogs.showToast(context, '已强制以本机修改为准同步');
              }
            },
            child: const Text(
              '以本机为准覆盖',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (latest != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '云端最新 (v${latest['version']}): ${latest['name']} · 数量 ${latest['quantity']} · 位置「${latest['location_detail'] ?? ''}」',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                ),
              if (localChanged != null && localChanged.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '本机离线修改: $localChanged',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

