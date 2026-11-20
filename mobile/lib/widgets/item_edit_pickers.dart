import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'custom_dialogs.dart';
import 'shad_sheet_option_tile.dart';

class ItemEditFieldLabel extends StatelessWidget {
  final String text;
  const ItemEditFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}

class ItemEditPickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const ItemEditPickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemEditFieldLabel(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemEditPickers {
  static Future<void> showHousePicker(
    BuildContext context, {
    required List<House> houses,
    required House? selected,
    required ValueChanged<House> onSelected,
  }) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: const Text(
          '选择所属房屋',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: houses
                  .map(
                    (h) => ShadSheetOptionTile(
                      leading:
                          Text(h.icon, style: const TextStyle(fontSize: 22)),
                      title: h.name,
                      selected: selected?.id == h.id,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelected(h);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showRoomPicker(
    BuildContext context, {
    required List<Room> rooms,
    required Room? selected,
    required ValueChanged<Room> onSelected,
  }) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: const Text(
          '选择功能房间',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView(
              shrinkWrap: true,
              children: rooms
                  .map(
                    (r) => ShadSheetOptionTile(
                      leading:
                          Text(r.icon, style: const TextStyle(fontSize: 22)),
                      title: r.name,
                      selected: selected?.id == r.id,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelected(r);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showCategoryPicker(
    BuildContext context, {
    required List<Category> categories,
    required Category? selected,
    required ValueChanged<Category?> onSelected,
  }) {
    final activeList = categories
        .where((c) => c.isActive || c.id == selected?.id)
        .toList();
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: const Text(
          '选择物品分类',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                ShadSheetOptionTile(
                  leading: const Text('📦', style: TextStyle(fontSize: 22)),
                  title: '未分类',
                  selected: selected == null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSelected(null);
                  },
                ),
                ...activeList.map(
                  (c) => ShadSheetOptionTile(
                    leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                    title: c.name,
                    selected: selected?.id == c.id,
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
      ),
    );
  }

  static Future<Item?> confirmAndFetchLatest(
    BuildContext context,
    int itemId,
  ) async {
    final shouldRefresh = await CustomDialogs.showConfirm(
      context: context,
      title: '检测到跨端编辑冲突',
      message: '该物品已在其他设备上更新，直接覆盖可能会丢失新修改或新附件。是否立即拉取最新版本？',
      confirmText: '刷新最新内容',
    );
    if (!shouldRefresh || !context.mounted) return null;
    try {
      return await ApiService.instance.getItemDetail(itemId);
    } catch (err) {
      if (context.mounted) {
        CustomDialogs.showToast(
          context,
          '拉取最新版本失败',
          description: ApiService.formatDioError(err),
          isError: true,
        );
      }
      return null;
    }
  }
}


class ItemEditQuantityStepper extends StatelessWidget {
  final TextEditingController controller;

  const ItemEditQuantityStepper({super.key, required this.controller});

  int get _currentValue => (int.tryParse(controller.text) ?? 1).clamp(1, 9999);

  void _step(int delta) {
    final next = (_currentValue + delta).clamp(1, 9999);
    controller.text = next.toString();
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final parsed = int.tryParse(value.text);
        final canDecrement = parsed != null && parsed > 1;

        return Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              final safe = (int.tryParse(controller.text) ?? 1).clamp(1, 9999);
              if (controller.text != safe.toString()) {
                controller.text = safe.toString();
              }
            }
          },
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onChanged: (raw) {
                      if (raw == '0') {
                        controller.text = '1';
                        controller.selection = const TextSelection.collapsed(offset: 1);
                      }
                    },
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0xFFE2E8F0)),
                SizedBox(
                  width: 34,
                  height: 40,
                  child: Column(
                    children: [
                      _StepperIconBtn(
                        icon: LucideIcons.chevronUp,
                        enabled: true,
                        activeColor: theme.primary,
                        onTap: () => _step(1),
                      ),
                      Container(
                        width: 34,
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                      _StepperIconBtn(
                        icon: LucideIcons.chevronDown,
                        enabled: canDecrement,
                        activeColor: theme.primary,
                        onTap: () => _step(-1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepperIconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color activeColor;
  final VoidCallback onTap;

  const _StepperIconBtn({
    required this.icon,
    required this.enabled,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 34,
        height: 19.5,
        child: Icon(
          icon,
          size: 14,
          color: enabled ? activeColor : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}
