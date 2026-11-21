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

/// 归还收纳独立页面（替代底部抽屉）：
/// 支持一键原位放回，或切换为更换位置/替换照片模式，像普通编辑页一样舒适填写。
class ItemPutBackScreen extends StatefulWidget {
  final Item item;
  final List<House> houses;
  final List<Room> rooms;

  const ItemPutBackScreen({
    super.key,
    required this.item,
    this.houses = const [],
    this.rooms = const [],
  });

  @override
  State<ItemPutBackScreen> createState() => _ItemPutBackScreenState();
}

class _ItemPutBackScreenState extends State<ItemPutBackScreen> {
  final _locationController = TextEditingController();
  final _tempTracker = SessionTempMediaTracker();

  bool _restoreOriginal = true;
  List<House> _houses = [];
  List<Room> _rooms = [];
  House? _selectedHouse;
  Room? _selectedRoom;
  late List<Map<String, dynamic>> _storageAttachments;
  late Set<String> _initialStoragePaths;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _houses = List.of(widget.houses);
    _rooms = List.of(widget.rooms);
    _initDefaults();
    if (_houses.isEmpty || _rooms.isEmpty) {
      _fetchSpaces();
    }
  }

  void _initDefaults() {
    final item = widget.item;
    final targetHouseId = item.storageHouseId ?? item.houseId;
    final targetRoomId = item.storageRoomId ?? item.roomId;
    _selectedHouse = _houses.where((h) => h.id == targetHouseId).firstOrNull ??
        _houses.where((h) => h.isActive).firstOrNull;
    _selectedRoom = _rooms.where((r) => r.id == targetRoomId).firstOrNull ??
        _rooms.where((r) => r.houseId == _selectedHouse?.id && r.isActive).firstOrNull;
    _locationController.text = item.storageLocationDetail;

    _storageAttachments = item.storageAttachments
        .map((a) => <String, dynamic>{
              'media_type': a.mediaType,
              'file_path': a.filePath,
              'thumbnail_path': a.thumbnailUrl
                  ?.replaceFirst('/api/media/file/', '')
                  .replaceFirst('/api/media/', ''),
              'file_size': a.fileSize,
              'duration_seconds': a.durationSeconds,
              'width': a.width,
              'height': a.height,
            })
        .toList();
    _initialStoragePaths =
        _storageAttachments.map((a) => a['file_path'] as String).toSet();
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
        final targetHouseId = widget.item.storageHouseId ?? widget.item.houseId;
        final targetRoomId = widget.item.storageRoomId ?? widget.item.roomId;
        _selectedHouse ??= _houses.where((h) => h.id == targetHouseId).firstOrNull ??
            _houses.where((h) => h.isActive).firstOrNull;
        _selectedRoom ??= _rooms.where((r) => r.id == targetRoomId).firstOrNull ??
            _rooms.where((r) => r.houseId == _selectedHouse?.id && r.isActive).firstOrNull;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tempTracker.cleanupAllRemaining();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitPutBack() async {
    if (!_restoreOriginal && (_selectedHouse == null || _selectedRoom == null)) {
      CustomDialogs.showToast(context, '请选择新的收纳房屋与房间', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final currentPaths =
          _storageAttachments.map((a) => a['file_path'] as String).toSet();
      final removedPaths = _initialStoragePaths.difference(currentPaths).toList();
      final addedAtts = _storageAttachments
          .where((a) => !_initialStoragePaths.contains(a['file_path']))
          .toList();

      await ApiService.instance.putBackItem(widget.item.id, {
        'restore_original': _restoreOriginal,
        if (!_restoreOriginal) 'house_id': _selectedHouse!.id,
        if (!_restoreOriginal) 'room_id': _selectedRoom!.id,
        if (!_restoreOriginal) 'location_detail': _locationController.text.trim(),
        if (addedAtts.isNotEmpty) 'added_storage_attachments': addedAtts,
        if (removedPaths.isNotEmpty) 'removed_attachment_paths': removedPaths,
        'expected_version': widget.item.version,
      });
      _tempTracker.clearSaved();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        CustomDialogs.showToast(
          context,
          '归还收纳失败',
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
    final origPath = item.storagePathDisplay ?? item.pathDisplay ?? '原位置';
    final origDetail = item.storageLocationDetail;

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: MainTopBar(
        title: '归还收纳',
        canNavigateBack: true,
        onMenuClick: () {},
        onNavigateBack: () => Navigator.of(context).pop(false),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  Text(
                    '${item.category?.icon ?? "📦"} ${item.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '归还后将自动清理使用中的临时实拍附件',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                        child: _ModeOptionChip(
                          label: '原位放回',
                          selected: _restoreOriginal,
                          color: theme.primary,
                          onTap: () => setState(() => _restoreOriginal = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeOptionChip(
                          label: '换位 / 换图',
                          selected: !_restoreOriginal,
                          color: theme.primary,
                          onTap: () => setState(() => _restoreOriginal = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_restoreOriginal)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '将恢复至：$origPath${origDetail.isNotEmpty ? " · $origDetail" : ""}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ItemEditPickerTile(
                            label: '新收纳房屋 *',
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
                            label: '新收纳房间 *',
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
                    const ItemEditFieldLabel('新收纳位置备注'),
                    ShadInput(
                      controller: _locationController,
                      placeholder: const Text('例如：换到白色大收纳箱'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    ItemEditMediaSection(
                      attachments: _storageAttachments,
                      tempTracker: _tempTracker,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ShadButton(
                      onPressed: _saving ? null : _submitPutBack,
                      child: Text(
                        _saving ? '处理中...' : '确认归还收纳',
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

class _ModeOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeOptionChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? color : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

