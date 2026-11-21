import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/offline_sync_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/item_detail_audio_section.dart';
import '../widgets/item_detail_header_card.dart';
import '../widgets/item_detail_image_grid.dart';
import '../widgets/item_detail_video_section.dart';
import '../widgets/lifecycle_action_icon.dart';
import '../widgets/main_top_bar.dart';
import 'item_edit_screen.dart';
import 'item_put_back_screen.dart';
import 'item_take_out_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final List<House> houses;
  final List<Room> rooms;
  final List<Category> categories;

  const ItemDetailScreen({
    super.key,
    required this.item,
    this.houses = const [],
    this.rooms = const [],
    this.categories = const [],
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Item _item;
  bool _hasChanged = false;
  bool _deleting = false;
  bool _updatingQty = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshLatestDetail();
  }

  Future<void> _refreshLatestDetail() async {
    try {
      final latest = await ApiService.instance.getItemDetail(_item.id);
      if (mounted) setState(() => _item = latest);
    } catch (_) {}
  }

  Future<void> _handleEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditScreen(
          initialItem: _item,
          houses: widget.houses,
          rooms: widget.rooms,
          categories: widget.categories,
        ),
      ),
    );
    if (saved == true) {
      _hasChanged = true;
      await _refreshLatestDetail();
      if (mounted) CustomDialogs.showToast(context, '物品信息已更新');
    }
  }

  Future<void> _handleLifecycleAction() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _item.isInUse
            ? ItemPutBackScreen(
                item: _item,
                houses: widget.houses,
                rooms: widget.rooms,
              )
            : ItemTakeOutScreen(
                item: _item,
                houses: widget.houses,
                rooms: widget.rooms,
              ),
      ),
    );
    if (ok == true) {
      _hasChanged = true;
      await _refreshLatestDetail();
      if (mounted) {
        CustomDialogs.showToast(
          context,
          _item.isInUse ? '物品已标记为取出使用' : '物品已归还收纳',
        );
      }
    }
  }

  Future<void> _handleStepQuantity(int delta) async {
    if (_updatingQty) return;
    final nextQty = _item.quantity + delta;
    if (nextQty < 0) return;

    if (delta < 0 && nextQty == 0) {
      final firstConfirm = await CustomDialogs.showConfirm(
        context: context,
        title: '数量已归零，是否删除？',
        message: '“${_item.name}”数量将变为 0。如需清理台账可删除该物品，也可保留数量 0。',
        confirmText: '删除物品',
        cancelText: '保留 (数量 0)',
        isDanger: true,
      );
      if (!mounted) return;
      if (firstConfirm) {
        final secondConfirm = await CustomDialogs.showConfirm(
          context: context,
          title: '再次确认删除？',
          message: '删除后将永久清理“${_item.name}”及其照片附件，无法恢复！',
          confirmText: '确认彻底删除',
          cancelText: '取消',
          isDanger: true,
        );
        if (!mounted) return;
        if (secondConfirm) {
          setState(() => _deleting = true);
          try {
            await OfflineSyncService.instance.saveOrQueueDelete(item: _item);
            if (mounted) {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            if (mounted) {
              setState(() => _deleting = false);
              CustomDialogs.showToast(context, '删除失败', description: ApiService.formatDioError(e), isError: true);
            }
          }
          return;
        }
      }
    }

    setState(() => _updatingQty = true);
    try {
      final updated = await ApiService.instance.updateItem(_item.id, {
        'quantity': nextQty,
        'expected_version': _item.version,
      });
      if (mounted) {
        HapticFeedback.selectionClick();
        setState(() {
          _item = updated;
          _hasChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(context, '更新数量失败', description: ApiService.formatDioError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _updatingQty = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await CustomDialogs.showConfirm(
      context: context,
      title: '确认删除该物品？',
      message: '删除后将永久清理“${_item.name}”及其关联的现场照片与音视频附件，无法恢复！',
      confirmText: '彻底删除',
      isDanger: true,
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      final queuedOffline =
          await OfflineSyncService.instance.saveOrQueueDelete(item: _item);
      if (mounted) {
        HapticFeedback.mediumImpact();
        if (queuedOffline) {
          CustomDialogs.showToast(context, '已加入离线删除队列');
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        CustomDialogs.showToast(
          context,
          '删除失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final images =
        _item.attachments.where((a) => a.mediaType == 'image').toList();
    final audios =
        _item.attachments.where((a) => a.mediaType == 'audio').toList();
    final videos =
        _item.attachments.where((a) => a.mediaType == 'video').toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_hasChanged);
      },
      child: Scaffold(
        backgroundColor: theme.pageBg,
        appBar: MainTopBar(
          title: '物品详情',
          canNavigateBack: true,
          onMenuClick: () {},
          onNavigateBack: () => Navigator.of(context).pop(_hasChanged),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 文本优先置顶展示核心信息卡片
              ItemDetailHeaderCard(item: _item),

              // 2. 实景照片区块（九宫格缩略图 + 半透明尺寸药丸）
              if (images.isNotEmpty) ...[
                const SizedBox(height: 14),
                ItemDetailImageGrid(images: images),
              ],

              // 3. 寻路短视频区块（轻量海报卡片列表 + 按需播放）
              if (videos.isNotEmpty) ...[
                const SizedBox(height: 14),
                ItemDetailVideoSection(videos: videos),
              ],

              // 4. 现场语音指引区块（极简圆角条状胶囊）
              if (audios.isNotEmpty) ...[
                const SizedBox(height: 14),
                ItemDetailAudioSection(audios: audios),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 快捷数量步进 (-1 / +1)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: (_updatingQty || _item.quantity <= 0)
                        ? null
                        : () => _handleStepQuantity(-1),
                    icon: const Icon(LucideIcons.minus, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '减少 1',
                  ),
                  Text(
                    '${_item.quantity}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: _updatingQty ? null : () => _handleStepQuantity(1),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '增加 1',
                  ),
                ],
              ),
            ),
            const Spacer(),
            Tooltip(
              message: '编辑物品信息',
              child: SizedBox(
                width: 52,
                height: 44,
                child: ShadButton.outline(
                  padding: EdgeInsets.zero,
                  onPressed: _handleEdit,
                  child: const Icon(
                    LucideIcons.pencil,
                    size: 18,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _item.isInUse ? '归还收纳' : '取出使用',
              child: SizedBox(
                width: 52,
                height: 44,
                child: ShadButton(
                  padding: EdgeInsets.zero,
                  backgroundColor: _item.isInUse
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  onPressed: _handleLifecycleAction,
                  child: LifecycleActionIcon(
                    isInUse: _item.isInUse,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '删除物品',
              child: SizedBox(
                width: 52,
                height: 44,
                child: ShadButton.destructive(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFFE11D48),
                  onPressed: _deleting ? null : _handleDelete,
                  child: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
