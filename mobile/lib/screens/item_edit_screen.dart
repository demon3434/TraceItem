import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/meta_snapshot_store.dart';
import '../core/offline_sync_service.dart';
import '../core/session_temp_media_tracker.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/item_edit_media_section.dart';
import '../widgets/item_edit_pickers.dart';
import '../widgets/main_top_bar.dart';
import '../widgets/tag_autocomplete_field.dart';

class ItemEditScreen extends StatefulWidget {
  final Item? initialItem;
  final House? defaultHouse;
  final Room? defaultRoom;
  final List<House> houses;
  final List<Room> rooms;
  final List<Category> categories;
  final bool embedded;
  final VoidCallback? onSavedEmbedded;

  const ItemEditScreen({
    super.key,
    this.initialItem,
    this.defaultHouse,
    this.defaultRoom,
    this.houses = const [],
    this.rooms = const [],
    this.categories = const [],
    this.embedded = false,
    this.onSavedEmbedded,
  });

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  final _descController = TextEditingController();

  List<House> _houses = [];
  List<Room> _rooms = [];
  List<Category> _categories = [];
  House? _selectedHouse;
  Room? _selectedRoom;
  Category? _selectedCategory;
  List<String> _tags = [];
  List<Map<String, dynamic>> _attachments = [];
  final SessionTempMediaTracker _tempMediaTracker = SessionTempMediaTracker();
  int? _editingVersion;
  bool _saving = false;
  bool _loadingMeta = false;

  bool get isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    _houses = List.of(widget.houses);
    _rooms = List.of(widget.rooms);
    _categories = List.of(widget.categories);
    _initFormValues();
    if (_houses.isEmpty || _rooms.isEmpty || _categories.isEmpty) {
      _fetchMeta();
    }
  }

  void _initFormValues() {
    final item = widget.initialItem;
    if (item != null) {
      _applyItemToForm(item);
    } else {
      _editingVersion = null;
      final activeHouses = _houses.where((h) => h.isActive).toList();
      final defaultH = widget.defaultHouse;
      _selectedHouse = (defaultH != null && defaultH.isActive)
          ? defaultH
          : activeHouses.firstOrNull;
      final defaultR = widget.defaultRoom;
      _selectedRoom = (defaultR != null &&
              _selectedHouse != null &&
              defaultR.houseId == _selectedHouse!.id &&
              defaultR.isActive)
          ? defaultR
          : _rooms
              .where((r) => r.houseId == _selectedHouse?.id && r.isActive)
              .firstOrNull;
    }
  }

  Future<void> _fetchMeta() async {
    setState(() => _loadingMeta = true);
    try {
      final results = await Future.wait([
        ApiService.instance.getHouses(),
        ApiService.instance.getRooms(),
        ApiService.instance.getCategories(),
      ]);
      if (!mounted) return;
      _houses = results[0] as List<House>;
      _rooms = results[1] as List<Room>;
      _categories = results[2] as List<Category>;
      if (_selectedHouse == null && _houses.isNotEmpty) {
        final activeHouses = _houses.where((h) => h.isActive).toList();
        final defaultH = widget.defaultHouse;
        _selectedHouse = (defaultH != null && defaultH.isActive)
            ? defaultH
            : activeHouses.firstOrNull;
      }
      if (_selectedRoom == null && _selectedHouse != null) {
        _selectedRoom = _rooms
            .where((r) => r.houseId == _selectedHouse!.id && r.isActive)
            .firstOrNull;
      }
      setState(() {});
    } catch (_) {
      final uid = ApiService.instance.currentUser?.id;
      if (uid != null && _houses.isEmpty) {
        final snap = await MetaSnapshotStore.loadSnapshot(uid);
        if (snap != null && mounted) {
          _houses = snap.houses;
          _rooms = snap.rooms;
          _categories = snap.categories;
          setState(() {});
        }
      }
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  @override
  void dispose() {
    _tempMediaTracker.cleanupAllRemaining();
    _nameController.dispose();
    _brandController.dispose();
    _qtyController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyItemToForm(Item item) {
    _editingVersion = item.version;
    _nameController.text = item.name;
    _brandController.text = item.brand;
    _qtyController.text = item.quantity.toString();
    _locationController.text = item.locationDetail;
    _descController.text = item.description;
    _tags = item.tags.map((t) => t.name).toList();
    _selectedHouse = _houses.where((h) => h.id == item.houseId).firstOrNull ??
        widget.defaultHouse ??
        _houses.firstOrNull;
    _selectedRoom =
        _rooms.where((r) => r.id == item.roomId).firstOrNull ?? widget.defaultRoom;
    _selectedCategory = item.categoryId != null
        ? _categories.where((c) => c.id == item.categoryId).firstOrNull ??
            item.category
        : null;
    _attachments = item.attachments
        .map(
          (a) => <String, dynamic>{
            'media_type': a.mediaType,
            'file_path': a.filePath,
            'thumbnail_path': a.thumbnailUrl
                ?.replaceFirst('/api/media/file/', '')
                .replaceFirst('/api/media/', ''),
            'file_size': a.fileSize,
            'duration_seconds': a.durationSeconds,
            'width': a.width,
            'height': a.height,
          },
        )
        .toList();
  }

  Future<void> _handleConflictRefresh() async {
    final item = widget.initialItem;
    if (item == null || !mounted) return;
    final latest = await ItemEditPickers.confirmAndFetchLatest(context, item.id);
    if (latest != null && mounted) {
      setState(() => _applyItemToForm(latest));
      CustomDialogs.showToast(context, '已同步最新版本，请确认后重新保存');
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      CustomDialogs.showToast(context, '请输入物品名称', isError: true);
      return;
    }
    if (_selectedHouse == null || _selectedRoom == null) {
      CustomDialogs.showToast(context, '请选择所属房屋与功能房间', isError: true);
      return;
    }
    if (!_attachments.any((a) => a['media_type'] == 'image')) {
      CustomDialogs.showToast(
        context,
        '请至少上传 1 张实景照片',
        description: '首张照片将作为物品卡片封面图',
        isError: true,
      );
      return;
    }

    for (int i = 0; i < _attachments.length; i++) {
      _attachments[i]['display_order'] = i + 1;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final payload = {
        'house_id': _selectedHouse!.id,
        'room_id': _selectedRoom!.id,
        'category_id': _selectedCategory?.id,
        'name': name,
        'brand': _brandController.text.trim(),
        'quantity': (int.tryParse(_qtyController.text) ?? 1).clamp(0, 9999),
        'location_detail': _locationController.text.trim(),
        'description': _descController.text.trim(),
        'tag_names': _tags,
        'attachments': _attachments,
      };

      var queuedOffline = false;
      if (isEditMode) {
        queuedOffline = await OfflineSyncService.instance.saveOrQueueUpdate(
          baseline: widget.initialItem!,
          fullPayload: payload,
          attachments: _attachments,
          expectedVersion: _editingVersion,
        );
      } else {
        queuedOffline = await OfflineSyncService.instance.saveOrQueueCreate(
          itemName: name,
          payload: payload,
          attachments: _attachments,
        );
      }

      _tempMediaTracker.clearSaved();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      if (widget.embedded) {
        CustomDialogs.showToast(context, queuedOffline ? '已保存至离线待同步队列' : '物品已归档入库');
        widget.onSavedEmbedded?.call();
      } else {
        if (queuedOffline) CustomDialogs.showToast(context, '已保存至离线待同步队列');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        if (ApiService.isConflictError(e)) {
          await _handleConflictRefresh();
        } else {
          CustomDialogs.showToast(
            context,
            '保存失败',
            description: ApiService.formatDioError(e),
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final selectableHouses = _houses
        .where((h) => h.isActive || h.id == widget.initialItem?.houseId)
        .toList();
    final roomsForHouse = _rooms
        .where(
          (r) =>
              r.houseId == _selectedHouse?.id &&
              (((_selectedHouse?.isActive ?? false) && r.isActive) ||
                  r.id == widget.initialItem?.roomId),
        )
        .toList();

    final body = _loadingMeta && _houses.isEmpty
        ? Center(child: CircularProgressIndicator(color: theme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: theme.ambientShadows,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ItemEditPickerTile(
                          label: '所属房屋 *',
                          value: _selectedHouse != null
                              ? '${_selectedHouse!.icon} ${_selectedHouse!.name}'
                              : '选择房屋',
                          onTap: () {
                            if (selectableHouses.isEmpty) {
                              CustomDialogs.showToast(
                                context,
                                '暂无可用启用房屋，请先创建或启用房屋',
                                isError: true,
                              );
                              return;
                            }
                            ItemEditPickers.showHousePicker(
                              context,
                              houses: selectableHouses,
                              selected: _selectedHouse,
                              onSelected: (h) {
                                setState(() {
                                  _selectedHouse = h;
                                  _selectedRoom = _rooms
                                      .where((r) =>
                                          r.houseId == h.id &&
                                          ((h.isActive && r.isActive) ||
                                              r.id == widget.initialItem?.roomId))
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
                          label: '功能房间 *',
                          value: _selectedRoom != null
                              ? '${_selectedRoom!.icon} ${_selectedRoom!.name}'
                              : '选择房间',
                          onTap: () {
                            if (roomsForHouse.isEmpty) {
                              CustomDialogs.showToast(
                                context,
                                '当前房屋暂无房间',
                                isError: true,
                              );
                              return;
                            }
                            ItemEditPickers.showRoomPicker(
                              context,
                              rooms: roomsForHouse,
                              selected: _selectedRoom,
                              onSelected: (r) =>
                                  setState(() => _selectedRoom = r),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ItemEditPickerTile(
                    label: '物品分类',
                    value: _selectedCategory != null
                        ? '${_selectedCategory!.icon} ${_selectedCategory!.name}'
                        : '📦 未分类',
                    onTap: () => ItemEditPickers.showCategoryPicker(
                      context,
                      categories: _categories,
                      selected: _selectedCategory,
                      onSelected: (c) =>
                          setState(() => _selectedCategory = c),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const ItemEditFieldLabel('物品名称 *'),
                  ShadInput(
                    controller: _nameController,
                    placeholder: const Text(
                      '小林退热贴、飞利浦电风扇',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ItemEditFieldLabel('品牌 / 型号'),
                            ShadInput(
                              controller: _brandController,
                              placeholder: const Text(
                                '小米、500ml、3号电池',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 104,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ItemEditFieldLabel('数量'),
                            ItemEditQuantityStepper(controller: _qtyController),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ItemEditFieldLabel('存放具体位置 (免配置橱柜表)'),
                  ShadInput(
                    controller: _locationController,
                    placeholder: const Text(
                      '电视柜左侧第 2 个抽屉',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TagAutocompleteField(
                    tags: _tags,
                    onChanged: (next) => setState(() => _tags = next),
                  ),
                  const SizedBox(height: 12),
                  const ItemEditFieldLabel('备忘说明'),
                  ShadInput(
                    controller: _descController,
                    maxLines: 3,
                    placeholder: const Text(
                      '2027年到期、需避光保存',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  ItemEditMediaSection(
                    attachments: _attachments,
                    tempTracker: _tempMediaTracker,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 48,
                    child: ShadButton(
                      onPressed: _saving ? null : _handleSave,
                      child: Text(
                        _saving
                            ? '保存中...'
                            : (isEditMode ? '更新并保存' : '保存并归档'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: MainTopBar(
        title: isEditMode ? '修改物品信息' : '登记新物品',
        canNavigateBack: true,
        onMenuClick: () {},
        onNavigateBack: () => Navigator.of(context).pop(false),
      ),
      body: body,
    );
  }
}
