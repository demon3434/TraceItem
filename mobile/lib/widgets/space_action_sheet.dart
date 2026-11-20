import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';
import 'shad_sheet_option_tile.dart';

/// 统一 ShadSheet 空间操作菜单（防误触，替代行内拥挤图标）
class SpaceActionMenuSheet {
  static Future<void> show({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onBrowse,
    VoidCallback? onAddChild,
    required VoidCallback onEdit,
    required bool isActive,
    required String toggleLabel,
    required VoidCallback onToggleStatus,
    required VoidCallback onDelete,
    required String deleteLabel,
  }) {
    final theme = ThemeController.instance.current;
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        description: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadSheetOptionTile(
                leading: Icon(
                  LucideIcons.compass,
                  size: 19,
                  color: theme.primary,
                ),
                title: '查看空间物品',
                onTap: () {
                  Navigator.of(ctx).pop();
                  onBrowse();
                },
              ),
              if (onAddChild != null)
                ShadSheetOptionTile(
                  leading: Icon(
                    LucideIcons.plus,
                    size: 19,
                    color: theme.primary,
                  ),
                  title: '在此添加功能房间',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAddChild();
                  },
                ),
              ShadSheetOptionTile(
                leading: const Icon(
                  LucideIcons.pencil,
                  size: 19,
                  color: Color(0xFF475569),
                ),
                title: '修改名称与图标',
                onTap: () {
                  Navigator.of(ctx).pop();
                  onEdit();
                },
              ),
              ShadSheetOptionTile(
                leading: Icon(
                  isActive ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 19,
                  color: isActive
                      ? const Color(0xFFD97706)
                      : const Color(0xFF059669),
                ),
                title: toggleLabel,
                titleColor: isActive
                    ? const Color(0xFFB45309)
                    : const Color(0xFF047857),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onToggleStatus();
                },
              ),
              ShadSheetOptionTile(
                leading: const Icon(
                  LucideIcons.trash2,
                  size: 19,
                  color: Color(0xFFE11D48),
                ),
                title: deleteLabel,
                titleColor: const Color(0xFFE11D48),
                margin: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

