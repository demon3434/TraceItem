import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import '../widgets/category_action_sheet.dart';
import '../widgets/category_emoji_picker_sheet.dart';
import '../widgets/custom_dialogs.dart';

class CategoryManageScreen extends StatefulWidget {
  final VoidCallback? onDataUpdated;

  const CategoryManageScreen({super.key, this.onDataUpdated});

  @override
  State<CategoryManageScreen> createState() => CategoryManageScreenState();
}

class CategoryManageScreenState extends State<CategoryManageScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  final TextEditingController _nameController = TextEditingController();
  String _selectedEmoji = '📦';

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    setState(() => _loading = true);
    try {
      final list =
          await ApiService.instance.getCategories(includeInactive: true);
      if (mounted) setState(() => _categories = list);
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '加载分类失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAdd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      CustomDialogs.showToast(context, '请输入分类名称', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await ApiService.instance.createCategory(
        name,
        _selectedEmoji,
        _categories.length + 1,
      );
      _nameController.clear();
      if (!mounted) return;
      CustomDialogs.showToast(context, '分类已创建');
      widget.onDataUpdated?.call();
      loadCategories();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '创建分类失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _handleEdit(Category cat) async {
    final editName = TextEditingController(text: cat.name);
    var editIcon = cat.icon;

    await CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ShadSheet(
          isScrollControlled: true,
          scrollPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          actionsPinned: false,
          actionsAxis: Axis.horizontal,
          expandActionsWhenTiny: false,
          radius: const BorderRadius.vertical(top: Radius.circular(24)),
          title: const Text(
            '修改物品分类',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          actions: [
            Expanded(
              child: ShadButton.outline(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShadButton(
                onPressed: () async {
                  final nextName = editName.text.trim();
                  if (nextName.isEmpty) return;
                  await ApiService.instance.updateCategory(
                    cat.id,
                    name: nextName,
                    icon: editIcon,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    CustomDialogs.showToast(context, '分类已更新');
                    widget.onDataUpdated?.call();
                    loadCategories();
                  }
                },
                child: const Text(
                  '保存修改',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                _buildEmojiTriggerButton(
                  emoji: editIcon,
                  theme: ThemeController.instance.current,
                  onTap: () async {
                    final picked = await CategoryEmojiPickerSheet.show(
                      ctx,
                      selectedEmoji: editIcon,
                    );
                    if (picked != null && ctx.mounted) {
                      setModalState(() => editIcon = picked);
                    }
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ShadInput(
                      controller: editName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    editName.dispose();
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    setState(() {});
    HapticFeedback.lightImpact();

    try {
      final futures = <Future>[];
      for (var i = 0; i < _categories.length; i++) {
        futures.add(
          ApiService.instance.updateCategory(
            _categories[i].id,
            sortOrder: i + 1,
          ),
        );
      }
      await Future.wait(futures);
      widget.onDataUpdated?.call();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '保存排序失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
        loadCategories();
      }
    }
  }

  void _openActions(Category cat) {
    HapticFeedback.lightImpact();
    CategoryActionMenuSheet.show(
      context: context,
      category: cat,
      onEdit: () => _handleEdit(cat),
      onToggleActive: () => _toggleActive(cat),
      onDelete: () => _deleteCategory(cat),
    );
  }

  Future<void> _toggleActive(Category cat) async {
    try {
      await ApiService.instance.toggleCategoryStatus(cat.id, !cat.isActive);
      widget.onDataUpdated?.call();
      loadCategories();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '状态切换失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    final ok = await CustomDialogs.showConfirm(
      context: context,
      title: '解绑并删除分类“${cat.name}”？',
      message: '若该分类下已关联收纳物品，系统会自动置空分类归属，绝不会删除任何物品实体。',
      confirmText: '确认解绑删除',
      isDanger: true,
    );
    if (!ok) return;
    try {
      await ApiService.instance.deleteCategory(cat.id);
      if (mounted) {
        CustomDialogs.showToast(context, '分类已安全移除');
        widget.onDataUpdated?.call();
        loadCategories();
      }
    } catch (e) {
      if (mounted) {
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

    return Column(
      children: [
        // 顶部快捷新建卡片
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: theme.ambientShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '新增私有物品分类',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildEmojiTriggerButton(
                    emoji: _selectedEmoji,
                    theme: theme,
                    onTap: () async {
                      final picked = await CategoryEmojiPickerSheet.show(
                        context,
                        selectedEmoji: _selectedEmoji,
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedEmoji = picked);
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShadInput(
                      controller: _nameController,
                      placeholder: const Text(
                        '输入分类名称 (如：烘焙调料)',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShadButton(
                    onPressed: _handleAdd,
                    leading: const Icon(LucideIcons.plus, size: 15),
                    child: const Text(
                      '添加',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 提示引导条
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 18, 4),
          child: Row(
            children: [
              Icon(
                LucideIcons.tag,
                size: 15,
                color: theme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '全部物品分类 (${_categories.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const Spacer(),
              const Text(
                '长按拖拽排序',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),

        // 分类列表
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.primary))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: _categories.length,
                  onReorderStart: (_) => HapticFeedback.mediumImpact(),
                  onReorderItem: _handleReorder,
                  proxyDecorator: (child, _, animation) => Material(
                    color: Colors.transparent,
                    shadowColor: Colors.black26,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(18),
                    child: child,
                  ),
                  itemBuilder: (_, idx) {
                    final cat = _categories[idx];
                    return Container(
                      key: ValueKey(cat.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: theme.ambientShadows,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openActions(cat),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // 分类 Emoji 图标
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.lightBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    cat.icon,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // 分类名称与状态描述（严格防溢出截断）
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: cat.isActive
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF94A3B8),
                                          decoration: cat.isActive
                                              ? TextDecoration.none
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        cat.isActive
                                            ? '启用中 · 可在录入与筛选展示'
                                            : '已停用 · 历史物品保留展示',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 状态轻量药丸徽标
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cat.isActive
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFF94A3B8)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    cat.isActive ? '启用' : '停用',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: cat.isActive
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // 统一更多操作菜单按钮
                                IconButton(
                                  tooltip: '分类操作菜单',
                                  icon: const Icon(
                                    LucideIcons.ellipsis,
                                    size: 19,
                                    color: Color(0xFF64748B),
                                  ),
                                  onPressed: () => _openActions(cat),
                                ),
                                const SizedBox(width: 2),

                                // 拖拽把手图标
                                ReorderableDragStartListener(
                                  index: idx,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    child: Icon(
                                      LucideIcons.gripVertical,
                                      size: 18,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmojiTriggerButton({
    required String emoji,
    required DopamineThemeConfig theme,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: '选择分类图标',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.lightBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}


