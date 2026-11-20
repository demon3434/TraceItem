import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/house_order_sheet.dart';
import '../widgets/house_room_form_sheet.dart';
import '../widgets/space_action_sheet.dart';
import '../widgets/space_manage_cards.dart';

class SpaceManageScreen extends StatefulWidget {
  final void Function(House? house, Room? room) onBrowseSpace;
  final VoidCallback? onDataUpdated;

  const SpaceManageScreen({
    super.key,
    required this.onBrowseSpace,
    this.onDataUpdated,
  });

  @override
  State<SpaceManageScreen> createState() => SpaceManageScreenState();
}

class SpaceManageScreenState extends State<SpaceManageScreen> {
  List<House> _houses = [];
  List<Room> _rooms = [];
  int? _selectedHouseId;
  bool _loading = true;
  bool _reorderingRooms = false;

  House? get _selectedHouse {
    if (_houses.isEmpty) return null;
    return _houses.where((h) => h.id == _selectedHouseId).firstOrNull ??
        _houses.first;
  }

  List<Room> get _currentHouseRooms {
    final house = _selectedHouse;
    if (house == null) return const [];
    return _rooms.where((r) => r.houseId == house.id).toList();
  }

  Map<int, int> get _roomCountsByHouse {
    final counts = <int, int>{};
    for (final room in _rooms) {
      counts[room.houseId] = (counts[room.houseId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    loadSpaces();
  }

  Future<void> loadSpaces({int? preferHouseId}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.getHouses(),
        ApiService.instance.getRooms(),
      ]);
      if (!mounted) return;
      _houses = results[0] as List<House>;
      _rooms = results[1] as List<Room>;
      final targetId = preferHouseId ?? _selectedHouseId;
      if (_houses.isEmpty) {
        _selectedHouseId = null;
      } else if (targetId != null && _houses.any((h) => h.id == targetId)) {
        _selectedHouseId = targetId;
      } else {
        _selectedHouseId = _houses.first.id;
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '加载空间失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void openCreateHouse() {
    final prevIds = _houses.map((h) => h.id).toSet();
    HouseRoomFormSheet.show(
      context,
      isHouse: true,
      defaultSortOrder: _houses.length + 1,
      onSaved: () async {
        await loadSpaces();
        final newHouse = _houses.where((h) => !prevIds.contains(h.id)).firstOrNull;
        if (newHouse != null && mounted) {
          setState(() => _selectedHouseId = newHouse.id);
        }
        widget.onDataUpdated?.call();
      },
    );
  }

  void _openCreateRoom(House house) {
    final count = _rooms.where((r) => r.houseId == house.id).length;
    HouseRoomFormSheet.show(
      context,
      isHouse: false,
      targetHouseId: house.id,
      defaultSortOrder: count + 1,
      onSaved: () {
        loadSpaces(preferHouseId: house.id);
        widget.onDataUpdated?.call();
      },
    );
  }

  void _openHouseOrderSheet() {
    if (_houses.isEmpty) return;
    HouseOrderSheet.show(
      context,
      houses: _houses,
      roomCounts: _roomCountsByHouse,
      onReordered: (updatedHouses) {
        if (!mounted) return;
        setState(() => _houses = updatedHouses);
        widget.onDataUpdated?.call();
      },
    );
  }

  Future<void> _onReorderRooms(int oldIndex, int newIndex) async {
    final house = _selectedHouse;
    if (house == null || _reorderingRooms) return;
    final currentRooms = _currentHouseRooms;
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= currentRooms.length ||
        newIndex < 0 ||
        newIndex >= currentRooms.length) {
      return;
    }

    final snapshot = List<Room>.from(_rooms);
    final reorderedHouseRooms = List<Room>.from(currentRooms);
    final moved = reorderedHouseRooms.removeAt(oldIndex);
    reorderedHouseRooms.insert(newIndex, moved);
    final otherRooms = _rooms.where((r) => r.houseId != house.id).toList();

    setState(() {
      _rooms = [...otherRooms, ...reorderedHouseRooms];
      _reorderingRooms = true;
    });

    try {
      final updated = await ApiService.instance.reorderRooms(
        house.id,
        reorderedHouseRooms.map((r) => r.id).toList(),
      );
      if (!mounted) return;
      setState(() => _rooms = [...otherRooms, ...updated]);
      HapticFeedback.lightImpact();
      widget.onDataUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _rooms = snapshot);
      CustomDialogs.showToast(
        context,
        '房间排序保存失败',
        description: ApiService.formatDioError(e),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _reorderingRooms = false);
    }
  }

  Future<void> _deleteHouse(House house) async {
    final confirmed = await CustomDialogs.showConfirm(
      context: context,
      title: '确认删除房屋“${house.name}”？',
      message: '将删除该空房屋及其名下空房间；若房屋内仍有物品，系统将拦截删除并建议改为停用。',
      confirmText: '确认删除房屋',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await ApiService.instance.deleteHouse(house.id);
      if (!mounted) return;
      CustomDialogs.showToast(context, '空房屋已删除');
      await loadSpaces();
      widget.onDataUpdated?.call();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '无法删除房屋',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await CustomDialogs.showConfirm(
      context: context,
      title: '确认删除房间“${room.name}”？',
      message: '将删除该空房间；若房间内仍有物品，系统将拦截删除并建议改为停用。',
      confirmText: '确认删除房间',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await ApiService.instance.deleteRoom(room.id);
      if (!mounted) return;
      CustomDialogs.showToast(context, '空房间已删除');
      await loadSpaces(preferHouseId: room.houseId);
      widget.onDataUpdated?.call();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '无法删除房间',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleHouseStatus(House house) async {
    final nextActive = !house.isActive;
    try {
      await ApiService.instance.toggleHouseStatus(house.id, nextActive);
      if (!mounted) return;
      CustomDialogs.showToast(
        context,
        nextActive ? '房屋已重新启用' : '房屋已停用',
        description: nextActive
            ? '现在可以继续向该房屋录入新物品'
            : '已有物品完好保留，可在首页开启「显示已停用空间」后查看',
      );
      await loadSpaces(preferHouseId: house.id);
      widget.onDataUpdated?.call();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '操作失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleRoomStatus(House house, Room room) async {
    final nextActive = !room.isActive;
    try {
      await ApiService.instance.toggleRoomStatus(room.id, nextActive);
      if (!mounted) return;
      CustomDialogs.showToast(
        context,
        nextActive ? '房间已重新启用' : '房间已停用',
        description: nextActive
            ? '现在可以继续向该房间录入新物品'
            : '已有物品完好保留，可在首页开启「显示已停用空间」后查看',
      );
      await loadSpaces(preferHouseId: house.id);
      widget.onDataUpdated?.call();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '操作失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  void _openHouseActions(House house) {
    final roomCount = _rooms.where((r) => r.houseId == house.id).length;
    SpaceActionMenuSheet.show(
      context: context,
      icon: house.icon,
      title: house.name,
      subtitle: house.isActive ? '包含 $roomCount 个功能房间' : '已停用 · 历史物品仍可查看',
      onBrowse: () => widget.onBrowseSpace(house, null),
      onAddChild: house.isActive ? () => _openCreateRoom(house) : null,
      onEdit: () => HouseRoomFormSheet.show(
        context,
        isHouse: true,
        editingHouse: house,
        onSaved: () {
          loadSpaces(preferHouseId: house.id);
          widget.onDataUpdated?.call();
        },
      ),
      isActive: house.isActive,
      toggleLabel: house.isActive ? '停用此房屋' : '启用此房屋',
      onToggleStatus: () => _toggleHouseStatus(house),
      onDelete: () => _deleteHouse(house),
      deleteLabel: '删除此房屋',
    );
  }

  void _openRoomActions(House house, Room room) {
    SpaceActionMenuSheet.show(
      context: context,
      icon: room.icon,
      title: room.name,
      subtitle:
          '所属房屋：${house.icon} ${house.name}${room.isActive ? '' : ' · 已停用'}',
      onBrowse: () => widget.onBrowseSpace(house, room),
      onEdit: () => HouseRoomFormSheet.show(
        context,
        isHouse: false,
        editingRoom: room,
        onSaved: () {
          loadSpaces(preferHouseId: house.id);
          widget.onDataUpdated?.call();
        },
      ),
      isActive: room.isActive,
      toggleLabel: room.isActive ? '停用此房间' : '启用此房间',
      onToggleStatus: () => _toggleRoomStatus(house, room),
      onDelete: () => _deleteRoom(room),
      deleteLabel: '删除此房间',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    if (_houses.isEmpty) {
      return _buildEmptyHousesState();
    }

    final house = _selectedHouse!;
    final houseRooms = _currentHouseRooms;

    return Column(
      children: [
        HouseSelectorRail(
          houses: _houses,
          selectedHouseId: house.id,
          onSelectHouse: (h) => setState(() => _selectedHouseId = h.id),
          onOpenHouseOrder: _openHouseOrderSheet,
        ),
        SelectedHouseHeaderCard(
          house: house,
          roomCount: houseRooms.length,
          onAddRoom: () => _openCreateRoom(house),
          onOpenActions: () => _openHouseActions(house),
        ),
        if (houseRooms.isNotEmpty)
          RoomsSectionHeader(roomCount: houseRooms.length),
        Expanded(
          child: RefreshIndicator(
            color: theme.primary,
            onRefresh: () => loadSpaces(preferHouseId: house.id),
            child: houseRooms.isEmpty
                ? _buildEmptyRoomsState(house)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(26, 2, 16, 90),
                    buildDefaultDragHandles: false,
                    itemCount: houseRooms.length,
                    onReorderStart: (_) => HapticFeedback.mediumImpact(),
                    onReorderItem: _onReorderRooms,
                    proxyDecorator: (child, _, __) => Material(
                      color: Colors.transparent,
                      elevation: 10,
                      borderRadius: BorderRadius.circular(20),
                      child: child,
                    ),
                    itemBuilder: (_, idx) {
                      final room = houseRooms[idx];
                      return RoomDragCard(
                        key: ValueKey('room_${room.id}'),
                        index: idx,
                        room: room,
                        onBrowse: () {},
                        onOpenActions: () => _openRoomActions(house, room),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHousesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏘️', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 16),
            const Text(
              '还没有创建房屋空间',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '先新建一个房屋（如“温馨小家”），再添加客厅、卧室等房间即可开始拍照收纳。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ShadButton(
              onPressed: openCreateHouse,
              leading: const Icon(LucideIcons.plus, size: 16),
              child: const Text(
                '新建第一个房屋',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoomsState(House house) {
    final theme = ThemeController.instance.current;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: theme.ambientShadows,
          ),
          child: Column(
            children: [
              const Text('🧸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                '「${house.name}」还没有房间',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '添加客厅、书房或儿童玩具角后，即可按房间拍照收纳并长按排序。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ShadButton(
                onPressed: () => _openCreateRoom(house),
                leading: const Icon(LucideIcons.plus, size: 16),
                child: const Text(
                  '添加第一个房间',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
