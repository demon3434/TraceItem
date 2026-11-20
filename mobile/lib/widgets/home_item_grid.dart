import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'home_empty_state.dart';
import 'item_card.dart';

/// 首页物品分页网格与全场景下拉刷新容器（支持少物品/空状态下拉与底部加载反馈）
class HomeItemGrid extends StatelessWidget {
  final List<Item> items;
  final bool loading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool loadMoreError;
  final bool isSearchOrFiltered;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<Item> onItemTap;

  const HomeItemGrid({
    super.key,
    required this.items,
    required this.loading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.loadMoreError,
    required this.isSearchOrFiltered,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetryLoadMore,
    required this.onAdd,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    if (loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        color: theme.primary,
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (_, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: HomeEmptyState(
                isSearch: isSearchOrFiltered,
                onAdd: onAdd,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 600,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.80,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, idx) {
                  final item = items[idx];
                  return MobileItemCard(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () => onItemTap(item),
                  );
                },
                childCount: items.length,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<int>) {
                    final idx = items.indexWhere((it) => it.id == key.value);
                    return idx >= 0 ? idx : null;
                  }
                  return null;
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              child: _buildFooter(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(DopamineThemeConfig theme) {
    if (isLoadingMore) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '正在加载更多物品...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (loadMoreError) {
      return Center(
        child: GestureDetector(
          onTap: onRetryLoadMore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.lightBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.refreshCw, size: 14, color: theme.primary),
                const SizedBox(width: 6),
                Text(
                  '加载失败，点击重试',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!hasMore) {
      return Center(
        child: Text(
          '已加载全部 ${items.length} 件物品',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

