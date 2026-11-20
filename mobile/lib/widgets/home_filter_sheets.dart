import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'custom_dialogs.dart';
import 'shad_sheet_option_tile.dart';

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final VoidCallback onVoiceTap;

  const HomeSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSearchChanged,
    required this.onClear,
    required this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: theme.ambientShadows,
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                LucideIcons.search,
                size: 17,
                color: Color(0xFF94A3B8),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: '名称、品牌、位置、分类、标签、备注',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: onClear,
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                HapticFeedback.lightImpact();
                onVoiceTap();
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.mic,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeFloatingAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const HomeFloatingAddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return Positioned(
      right: 16,
      bottom: 18,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: theme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.36),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.camera, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                '登记收纳',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeFilterSheets {
  static Future<void> showRoomPicker(
    BuildContext context, {
    required List<Room> rooms,
    required Room? activeRoom,
    required ValueChanged<Room?> onSelected,
  }) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: const Text(
          '选择房间',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView(
              shrinkWrap: true,
              children: [
                ShadSheetOptionTile(
                  leading: const Text('🌟', style: TextStyle(fontSize: 22)),
                  title: '全部房间',
                  selected: activeRoom == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(null);
                  },
                ),
                ...rooms.map(
                  (r) => ShadSheetOptionTile(
                    leading: Text(r.icon, style: const TextStyle(fontSize: 22)),
                    title: r.isActive ? r.name : '${r.name} (已停用)',
                    selected: activeRoom?.id == r.id,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(r);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showHousePicker(
    BuildContext context, {
    required List<House> houses,
    required House? activeHouse,
    required bool showInactiveSpaces,
    required ValueChanged<bool> onToggleShowInactive,
    required ValueChanged<House?> onSelected,
  }) {
    final hasInactive = houses.any((h) => !h.isActive);
    bool showInactive = showInactiveSpaces;
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visibleHouses = showInactive
              ? houses
              : houses.where((h) => h.isActive).toList();
          return ShadSheet(
            radius: const BorderRadius.vertical(top: Radius.circular(24)),
            title: const Text(
              '选择房屋',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasInactive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          final next = !showInactive;
                          setSheetState(() => showInactive = next);
                          onToggleShowInactive(next);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                showInactive
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff,
                                size: 17,
                                color: const Color(0xFF475569),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '显示已停用空间',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              Text(
                                showInactive ? '已开启' : '已隐藏',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ShadSheetOptionTile(
                          leading:
                              const Text('🌟', style: TextStyle(fontSize: 22)),
                          title: '全部空间物品',
                          selected: activeHouse == null,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onSelected(null);
                          },
                        ),
                        ...visibleHouses.map(
                          (h) => ShadSheetOptionTile(
                            leading: Text(
                              h.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: h.isActive ? h.name : '${h.name} (已停用)',
                            selected: activeHouse?.id == h.id,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onSelected(h);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> showCategoryPicker(
    BuildContext context, {
    required List<Category> categories,
    required Category? selectedCategory,
    required ValueChanged<Category?> onSelected,
  }) {
    final theme = ThemeController.instance.current;
    final activeCats = categories.where((c) => c.isActive).toList();
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: Text(
          '按物品分类筛选 (${activeCats.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                theme: theme,
                label: '🌟 全部品类',
                selected: selectedCategory == null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onSelected(null);
                },
              ),
              ...activeCats.map(
                (c) => _FilterChip(
                  theme: theme,
                  label: '${c.icon} ${c.name}',
                  selected: selectedCategory?.id == c.id,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSelected(c);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final DopamineThemeConfig theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? theme.primaryGradient : null,
          color: selected ? null : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

class HomeStatusRow extends StatelessWidget {
  final int itemCount;
  final bool isSearching;
  final bool isAnchorLocked;

  const HomeStatusRow({
    super.key,
    required this.itemCount,
    required this.isSearching,
    required this.isAnchorLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isSearching ? '搜索到 $itemCount 件结果' : '共 $itemCount 件物品',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isAnchorLocked)
            const Row(
              children: [
                Icon(LucideIcons.lock, size: 13, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  '空间已锁定',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
