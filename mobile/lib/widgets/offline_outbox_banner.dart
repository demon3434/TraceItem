import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/offline_sync_service.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';
import 'offline_outbox_sheet.dart';

/// 首页顶部「待同步草稿」状态胶囊与半屏管理抽屉入口
class OfflineOutboxBanner extends StatelessWidget {
  const OfflineOutboxBanner({super.key});

  /// 供首页横幅与全局顶栏统一唤起待同步草稿管理抽屉
  static Future<void> showDraftsSheet(BuildContext context) {
    return OfflineOutboxSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineSyncService.instance,
      builder: (context, _) {
        final drafts = OfflineSyncService.instance.drafts;
        if (drafts.isEmpty) return const SizedBox.shrink();

        final syncing = OfflineSyncService.instance.isSyncing;
        final conflictCount =
            drafts.where((d) => d.status == 'conflict').length;
        final failedCount = drafts.where((d) => d.status == 'failed').length;
        final hasAlert = conflictCount > 0 || failedCount > 0;
        final theme = ThemeController.instance.current;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                showDraftsSheet(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: hasAlert ? const Color(0xFFFFF1F2) : theme.lightBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasAlert
                            ? LucideIcons.triangleAlert
                            : LucideIcons.cloudUpload,
                        size: 18,
                        color: hasAlert
                            ? const Color(0xFFE11D48)
                            : theme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '待同步草稿 (${drafts.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            syncing
                                ? '正在自动同步至云端...'
                                : conflictCount > 0
                                    ? '$conflictCount 项存在并发冲突，点击仲裁'
                                    : failedCount > 0
                                        ? '$failedCount 项同步失败，点击查看原因或重试'
                                        : '网络恢复后自动上传，点击可管理',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: syncing
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final count = await OfflineSyncService.instance
                                  .syncCurrentUser(includeFailed: true);
                              if (!context.mounted) return;
                              if (count > 0) {
                                CustomDialogs.showToast(
                                  context,
                                  '已同步 $count 件物品',
                                );
                              } else if (OfflineSyncService
                                  .instance.drafts.isNotEmpty) {
                                showDraftsSheet(context);
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: syncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '立即同步',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
