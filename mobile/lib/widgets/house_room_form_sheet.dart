import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/generated/shared_space_emojis.g.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'custom_dialogs.dart';

class HouseRoomFormSheet extends StatefulWidget {
  final bool isHouse;
  final House? editingHouse;
  final Room? editingRoom;
  final int? targetHouseId;
  final int defaultSortOrder;
  final VoidCallback onSaved;

  const HouseRoomFormSheet({
    super.key,
    required this.isHouse,
    this.editingHouse,
    this.editingRoom,
    this.targetHouseId,
    this.defaultSortOrder = 1,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isHouse,
    House? editingHouse,
    Room? editingRoom,
    int? targetHouseId,
    int defaultSortOrder = 1,
    required VoidCallback onSaved,
  }) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (_) => HouseRoomFormSheet(
        isHouse: isHouse,
        editingHouse: editingHouse,
        editingRoom: editingRoom,
        targetHouseId: targetHouseId,
        defaultSortOrder: defaultSortOrder,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<HouseRoomFormSheet> createState() => _HouseRoomFormSheetState();
}

class _HouseRoomFormSheetState extends State<HouseRoomFormSheet> {
  static const List<SharedSpaceEmojiOption> _houseEmojis = kSharedHouseEmojis;
  static const List<SharedSpaceEmojiOption> _roomEmojis = kSharedRoomEmojis;

  late final TextEditingController _nameController;
  late String _selectedIcon;
  bool _saving = false;

  bool get _isEdit =>
      widget.isHouse ? widget.editingHouse != null : widget.editingRoom != null;

  @override
  void initState() {
    super.initState();
    if (widget.isHouse) {
      _nameController =
          TextEditingController(text: widget.editingHouse?.name ?? '');
      _selectedIcon = widget.editingHouse?.icon ?? _houseEmojis.first.icon;
    } else {
      _nameController =
          TextEditingController(text: widget.editingRoom?.name ?? '');
      _selectedIcon = widget.editingRoom?.icon ?? _roomEmojis.first.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      CustomDialogs.showToast(
        context,
        widget.isHouse ? '请输入房屋名称' : '请输入房间名称',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      if (widget.isHouse) {
        if (widget.editingHouse != null) {
          await ApiService.instance.updateHouse(
            widget.editingHouse!.id,
            name: name,
            icon: _selectedIcon,
          );
        } else {
          await ApiService.instance.createHouse(
            name,
            _selectedIcon,
            widget.defaultSortOrder,
          );
        }
      } else {
        if (widget.editingRoom != null) {
          await ApiService.instance.updateRoom(
            widget.editingRoom!.id,
            name: name,
            icon: _selectedIcon,
          );
        } else {
          await ApiService.instance.createRoom(
            name,
            _selectedIcon,
            widget.targetHouseId!,
            widget.defaultSortOrder,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      CustomDialogs.showToast(context, _isEdit ? '修改已保存' : '创建成功');
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '操作失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final emojiList = widget.isHouse ? _houseEmojis : _roomEmojis;
    final title = widget.isHouse
        ? (_isEdit ? '修改房屋信息' : '新建房屋空间')
        : (_isEdit ? '修改功能房间' : '新建功能房间');

    return ShadSheet(
      isScrollControlled: true,
      scrollPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      actionsPinned: false,
      actionsAxis: Axis.horizontal,
      expandActionsWhenTiny: false,
      radius: const BorderRadius.vertical(top: Radius.circular(24)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      description: Text(
        widget.isHouse ? '选择建筑图腾与房屋名称' : '橱柜、抽屉无需建表，通过照片视频直观留痕',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      actions: [
        Expanded(
          child: ShadButton.outline(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShadButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving ? '保存中...' : (_isEdit ? '保存修改' : '立即创建'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isHouse ? '房屋建筑图标' : '房间功能图标',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: emojiList.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, idx) {
                  final entry = emojiList[idx];
                  final selected = entry.icon == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = entry.icon),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: selected ? theme.primaryGradient : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? theme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.isHouse ? '房屋名称 *' : '房间名称 *',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ShadInput(
                controller: _nameController,
                placeholder: Text(
                  widget.isHouse ? '例如：幸福里新家 / 老家小院' : '例如：儿童玩具角 / 主卧衣帽间',
                  style: const TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

