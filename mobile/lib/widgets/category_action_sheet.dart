import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/models.dart';
import 'custom_dialogs.dart';
import 'shad_sheet_option_tile.dart';

/// 统一 ShadSheet 分类操作菜单（防误触，替代卡片行内拥挤的按钮）
class CategoryActionMenuSheet {
  static Future<void> show({
    required BuildContext context,
    required Category category,
    required VoidCallback onEdit,
    required VoidCallback onToggleActive,
    required VoidCallback onDelete,
  }) {
    final isActive = category.isActive;

    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: Row(
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
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
          isActive ? '当前状态：已启用 · 正常在录入与筛选中展示' : '当前状态：已停用 · 历史物品中保留展示',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      : const Color(0xFF10B981),
                ),
                title: isActive ? '停用此分类' : '启用此分类',
                titleColor: isActive
                    ? const Color(0xFFD97706)
                    : const Color(0xFF10B981),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onToggleActive();
                },
              ),
              ShadSheetOptionTile(
                leading: const Icon(
                  LucideIcons.trash2,
                  size: 19,
                  color: Color(0xFFE11D48),
                ),
                title: '解绑并删除分类',
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
