import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';

class SpaceAnchorBar extends StatelessWidget {
  final House? activeHouse;
  final Room? activeRoom;
  final Category? selectedCategory;
  final bool isAnchorLocked;
  final VoidCallback onOpenHousePicker;
  final VoidCallback onOpenRoomPicker;
  final VoidCallback onOpenCategoryPicker;
  final VoidCallback onToggleAnchor;

  const SpaceAnchorBar({
    super.key,
    required this.activeHouse,
    required this.activeRoom,
    required this.selectedCategory,
    required this.isAnchorLocked,
    required this.onOpenHousePicker,
    required this.onOpenRoomPicker,
    required this.onOpenCategoryPicker,
    required this.onToggleAnchor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticFeedback.lightImpact();
                  onOpenHousePicker();
                },
                child: _buildDropdownPill(
                  theme: theme,
                  icon: activeHouse?.icon ?? '🌟',
                  label: activeHouse?.name ?? '全部空间',
                  maxLabelWidth: 96,
                  isHighlighted: true,
                ),
              ),
            ),
            if (activeHouse != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    HapticFeedback.lightImpact();
                    onOpenRoomPicker();
                  },
                  child: _buildDropdownPill(
                    theme: theme,
                    icon: activeRoom?.icon ?? '🚪',
                    label: activeRoom?.name ?? '全部房间',
                    maxLabelWidth: 84,
                    isHighlighted: activeRoom != null,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                HapticFeedback.lightImpact();
                onOpenCategoryPicker();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selectedCategory != null
                      ? theme.lightBg
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedCategory != null
                        ? theme.primary
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  selectedCategory?.icon ?? '🏷️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (activeRoom != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggleAnchor();
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isAnchorLocked
                        ? const Color(0xFF10B981).withValues(alpha: 0.14)
                        : theme.lightBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAnchorLocked
                          ? const Color(0xFF10B981)
                          : theme.lightBorder,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.anchor,
                    size: 14,
                    color: isAnchorLocked
                        ? const Color(0xFF059669)
                        : theme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required DopamineThemeConfig theme,
    required String icon,
    required String label,
    required double maxLabelWidth,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? theme.lightBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? theme.lightBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? theme.darkText : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            LucideIcons.chevronsUpDown,
            size: 13,
            color: isHighlighted ? theme.primary : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}
