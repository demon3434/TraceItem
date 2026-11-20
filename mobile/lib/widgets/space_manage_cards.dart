import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';

/// 顶部横向房屋切换胶囊轨 + 「调整顺序」入口
class HouseSelectorRail extends StatelessWidget {
  final List<House> houses;
  final int? selectedHouseId;
  final ValueChanged<House> onSelectHouse;
  final VoidCallback onOpenHouseOrder;

  const HouseSelectorRail({
    super.key,
    required this.houses,
    required this.selectedHouseId,
    required this.onSelectHouse,
    required this.onOpenHouseOrder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: houses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final house = houses[idx];
                  final selected = house.id == selectedHouseId;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelectHouse(house);
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      onOpenHouseOrder();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected ? theme.primaryGradient : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.24),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(house.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              house.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onOpenHouseOrder();
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.lightBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.lightBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.arrowUpDown,
                    size: 15,
                    color: theme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '排序',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前选中房屋摘要卡片（主题浅色底横幅，明确父级容器归属）
class SelectedHouseHeaderCard extends StatelessWidget {
  final House house;
  final int roomCount;
  final VoidCallback onAddRoom;
  final VoidCallback onOpenActions;

  const SelectedHouseHeaderCard({
    super.key,
    required this.house,
    required this.roomCount,
    required this.onAddRoom,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.lightBg, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.lightBorder, width: 1.4),
        boxShadow: theme.ambientShadows,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: theme.primaryGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(house.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    house.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!house.isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      '已停用',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '房屋更多操作',
            icon: Icon(
              LucideIcons.ellipsis,
              size: 20,
              color: theme.darkText,
            ),
            onPressed: onOpenActions,
          ),
        ],
      ),
    );
  }
}

/// 房屋与下属房间层级引导条
class RoomsSectionHeader extends StatelessWidget {
  final int roomCount;

  const RoomsSectionHeader({super.key, required this.roomCount});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 18, 6),
      child: Row(
        children: [
          Icon(
            LucideIcons.cornerDownRight,
            size: 16,
            color: theme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '下属功能房间 ($roomCount)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单层房间拖拽卡片
class RoomDragCard extends StatelessWidget {
  final int index;
  final Room room;
  final VoidCallback onBrowse;
  final VoidCallback onOpenActions;

  const RoomDragCard({
    super.key,
    required this.index,
    required this.room,
    required this.onBrowse,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.lightImpact();
              onBrowse();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      color: theme.lightBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.gripVertical,
                    size: 17,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.lightBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      room.icon,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: room.isActive
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        if (!room.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '已停用',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '房间操作菜单',
                    icon: const Icon(
                      LucideIcons.ellipsis,
                      size: 19,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: onOpenActions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
