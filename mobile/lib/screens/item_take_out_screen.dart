import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/session_temp_media_tracker.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/item_edit_media_section.dart';
import '../widgets/item_edit_pickers.dart';
import '../widgets/main_top_bar.dart';

/// 物品长期取出使用登记页：
/// 基本属性（名称、品牌、分类、标签、数量）只读带入不可修改；
/// 仅开放当前所在房屋/房间、位置备注编辑，且附件区清空并强制至少上传 1 张照片。
class ItemTakeOutScreen extends StatefulWidget {
  final Item item;
  final List<House> houses;
  final List<Room> rooms;

  const ItemTakeOutScreen({
    super.key,
    required this.item,
    this.houses = const [],
    this.rooms = const [],
  });

  @override
  State<ItemTakeOutScreen> createState() => _ItemTakeOutScreenState();
}

class _ItemTakeOutScreenState extends State<ItemTakeOutScreen> {
  final _locationController = TextEditingController();
  final _tempMediaTracker = SessionTempMediaTracker();

  List<House> _houses = [];
  List<Room> _rooms = [];
  House? _selectedHouse;
  Room? _selectedRoom;
  final List<Map<String, dynamic>> _attachments = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _houses = List.of(widget.houses);
    _rooms = List.of(widget.rooms);
    _selectedHouse = _houses.where((h) => h.id == widget.item.houseId).firstOrNull ??
        _houses.where((h) => h.isActive).firstOrNull;
    _selectedRoom = _rooms.where((r) => r.id == widget.item.roomId).firstOrNull ??
        _rooms.where((r) => r.houseId == _selectedHouse?.id && r.isActive).firstOrNull;
    if (_houses.isEmpty || _rooms.isEmpty) {
      _fetchSpaces();
    }
  }

  Future<void> _fetchSpaces() async {
    try {
      final results = await Future.wait([
        ApiService.instance.getHouses(),
        ApiService.instance.getRooms(),
      ]);
      if (!mounted) return;
      setState(() {
        _houses = results[0] as List<House>;
        _rooms = results[1] as List<Room>;
        _selectedHouse ??= _houses.where((h) => h.id == widget.item.houseId).firstOrNull ??
            _houses.where((h) => h.isActive).firstOrNull;
        _selectedRoom ??= _rooms.where((r) => r.id == widget.item.roomId).firstOrNull ??
            _rooms.where((r) => r.houseId == _selectedHouse?.id && r.isActive).firstOrNull;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tempMediaTracker.cleanupAllRemaining();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedHouse == null || _selectedRoom == null) {
      CustomDialogs.showToast(context, '请选择当前所在房屋与房间', isError: true);
      return;
    }
    if (!_attachments.any((a) => a['media_type'] == 'image')) {
      CustomDialogs.showToast(
        context,
        '请至少拍摄或上传 1 张当前实景照片',
        description: '用于确认物品取出后的当前摆放位置',
        isError: true,
      );
      return;
    }
    for (int i = 0; i < _attachments.length; i++) {
      _attachments[i]['display_order'] = i + 1;
      _attachments[i]['scene'] = 'in_use';
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ApiService.instance.takeOutItem(widget.item.id, {
        'house_id': _selectedHouse!.id,
        'room_id': _selectedRoom!.id,
        'location_detail': _locationController.text.trim(),
        'attachments': _attachments,
        'expected_version': widget.item.version,
      });
      _tempMediaTracker.clearSaved();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        CustomDialogs.showToast(
          context,
          '取出登记失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final item = widget.item;

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: MainTopBar(
        title: '取出使用登记',
        canNavigateBack: true,
        onMenuClick: () {},
        onNavigateBack: () => Navigator.of(context).pop(false),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 只读基础信息卡片
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: theme.ambientShadows,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.category?.icon ?? '📦', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.lightBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.brand.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '品牌规格：${item.brand}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '原收纳位置：${item.pathDisplay ?? "未分配"}${item.locationDetail.isNotEmpty ? " · ${item.locationDetail}" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 当前使用位置选择
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: theme.ambientShadows,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ItemEditPickerTile(
                          label: '当前房屋 *',
                          value: _selectedHouse != null
                              ? '${_selectedHouse!.icon} ${_selectedHouse!.name}'
                              : '选择房屋',
                          onTap: () {
                            final activeHouses = _houses.where((h) => h.isActive).toList();
                            if (activeHouses.isEmpty) {
                              CustomDialogs.showToast(context, '暂无可用房屋', isError: true);
                              return;
                            }
                            ItemEditPickers.showHousePicker(
                              context,
                              houses: activeHouses,
                              selected: _selectedHouse,
                              onSelected: (h) {
                                setState(() {
                                  _selectedHouse = h;
                                  _selectedRoom = _rooms
                                      .where((r) => r.houseId == h.id && r.isActive)
                                      .firstOrNull;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ItemEditPickerTile(
                          label: '当前房间 *',
                          value: _selectedRoom != null
                              ? '${_selectedRoom!.icon} ${_selectedRoom!.name}'
                              : '选择房间',
                          onTap: () {
                            final roomsForHouse = _rooms
                                .where((r) => r.houseId == _selectedHouse?.id && r.isActive)
                                .toList();
                            if (roomsForHouse.isEmpty) {
                              CustomDialogs.showToast(context, '当前房屋暂无房间', isError: true);
                              return;
                            }
                            ItemEditPickers.showRoomPicker(
                              context,
                              rooms: roomsForHouse,
                              selected: _selectedRoom,
                              onSelected: (r) => setState(() => _selectedRoom = r),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ItemEditFieldLabel('当前摆放位置备注'),
                  ShadInput(
                    controller: _locationController,
                    placeholder: const Text(
                      '例如：客厅沙发旁、卧室门后',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ItemEditMediaSection(
                    attachments: _attachments,
                    tempTracker: _tempMediaTracker,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ShadButton(
                      onPressed: _saving ? null : _handleSubmit,
                      child: Text(
                        _saving ? '提交中...' : '确认取出并保存',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
