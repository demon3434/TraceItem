import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/category_emojis.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';

/// 移动端分类 Emoji 分组选择器（底部 ShadSheet，与 Web 端 6 组 192 款完全对齐）。
class CategoryEmojiPickerSheet extends StatefulWidget {
  final String selectedEmoji;

  const CategoryEmojiPickerSheet({
    super.key,
    required this.selectedEmoji,
  });

  static Future<String?> show(
    BuildContext context, {
    required String selectedEmoji,
  }) {
    return CustomDialogs.showModalSheet<String>(
      context: context,
      builder: (_) => CategoryEmojiPickerSheet(selectedEmoji: selectedEmoji),
    );
  }

  @override
  State<CategoryEmojiPickerSheet> createState() =>
      _CategoryEmojiPickerSheetState();
}

class _CategoryEmojiPickerSheetState extends State<CategoryEmojiPickerSheet> {
  late String _activeGroupName;

  @override
  void initState() {
    super.initState();
    _activeGroupName = findCategoryEmojiGroupName(widget.selectedEmoji);
  }

  CategoryEmojiGroup get _currentGroup => kCategoryEmojiGroups.firstWhere(
        (g) => g.name == _activeGroupName,
        orElse: () => kCategoryEmojiGroups.first,
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final group = _currentGroup;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 520 ? 8 : 6;

    return ShadSheet(
      radius: const BorderRadius.vertical(top: Radius.circular(24)),
      title: const Text(
        '✨ 挑选分类小图标',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      description: Text(
        '共 $kCategoryEmojiTotalCount 款精选图标 · 点击任意图标即可选定',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupSelector(theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 256),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: group.emojis.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (_, idx) {
                    final emoji = group.emojis[idx];
                    return _EmojiGridCell(
                      emoji: emoji,
                      selected: emoji == widget.selectedEmoji,
                      theme: theme,
                      onTap: () => Navigator.of(context).pop(emoji),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '当前图标：',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      widget.selectedEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
                Text(
                  '${group.label} · 共 ${group.emojis.length} 款',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector(DopamineThemeConfig theme) {
    final firstRow = kCategoryEmojiGroups.take(3).toList();
    final secondRow = kCategoryEmojiGroups.skip(3).take(3).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGroupRow(firstRow, theme),
        const SizedBox(height: 8),
        _buildGroupRow(secondRow, theme),
      ],
    );
  }

  Widget _buildGroupRow(
    List<CategoryEmojiGroup> groups,
    DopamineThemeConfig theme,
  ) {
    return Row(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildGroupTab(groups[i], theme)),
        ],
      ],
    );
  }

  Widget _buildGroupTab(CategoryEmojiGroup group, DopamineThemeConfig theme) {
    final active = group.name == _activeGroupName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (active) return;
        HapticFeedback.selectionClick();
        setState(() => _activeGroupName = group.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? theme.primaryGradient : null,
          color: active ? null : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? theme.primary : const Color(0xFFE2E8F0),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(group.icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiGridCell extends StatefulWidget {
  final String emoji;
  final bool selected;
  final DopamineThemeConfig theme;
  final VoidCallback onTap;

  const _EmojiGridCell({
    required this.emoji,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_EmojiGridCell> createState() => _EmojiGridCellState();
}

class _EmojiGridCellState extends State<_EmojiGridCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: widget.selected ? widget.theme.lightBg : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected
                  ? widget.theme.primary
                  : const Color(0xFFE2E8F0),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 23),
          ),
        ),
      ),
    );
  }
}

