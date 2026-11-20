import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/network_route_manager.dart';
import '../core/offline_sync_service.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';

class MainTopBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool canNavigateBack;
  final VoidCallback onMenuClick;
  final VoidCallback? onNavigateBack;
  final Future<void> Function()? onSyncPressed;
  final List<Widget> actions;

  const MainTopBar({
    super.key,
    required this.title,
    this.canNavigateBack = false,
    required this.onMenuClick,
    this.onNavigateBack,
    this.onSyncPressed,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<MainTopBar> createState() => _MainTopBarState();
}

class _MainTopBarState extends State<MainTopBar> {
  final ShadPopoverController _popoverController = ShadPopoverController();
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    NetworkRouteManager.instance.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    NetworkRouteManager.instance.removeListener(_onRouteChanged);
    _popoverController.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSyncTap() async {
    if (_isManualSyncing || widget.onSyncPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isManualSyncing = true);
    try {
      await widget.onSyncPressed!.call();
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final routeMgr = NetworkRouteManager.instance;
    final routeType = routeMgr.currentRouteType;

    final IconData routeIcon;
    final Color routeColor;
    final String routeTitle;
    final String routeBadge;

    if (routeMgr.isOffline) {
      routeIcon = LucideIcons.cloudOff;
      routeColor = const Color(0xFF94A3B8);
      routeTitle = '网络已断开';
      routeBadge = '当前处于离线状态';
    } else {
      switch (routeType) {
        case ActiveRouteType.intranet:
          routeIcon = LucideIcons.router;
          routeColor = const Color(0xFF10B981);
          routeTitle = '家庭局域网 (内网)';
          routeBadge = '✨ 局域网极速直连中';
        case ActiveRouteType.extranet:
          routeIcon = LucideIcons.globe;
          routeColor = const Color(0xFF0EA5E9);
          routeTitle = '互联网外网通道';
          routeBadge = '☁️ 云端外网安全线路';
        case ActiveRouteType.custom:
          routeIcon = LucideIcons.server;
          routeColor = const Color(0xFFF59E0B);
          routeTitle = '自定义服务节点';
          routeBadge = '⚡ 自定义节点连接中';
        case ActiveRouteType.unconfigured:
          routeIcon = LucideIcons.cloudOff;
          routeColor = const Color(0xFF94A3B8);
          routeTitle = '未配置服务地址';
          routeBadge = '请前往设置配置服务地址';
      }
    }

    return AppBar(
      backgroundColor: theme.pageBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        tooltip: widget.canNavigateBack ? '返回' : '打开菜单',
        icon: Icon(
          widget.canNavigateBack ? LucideIcons.arrowLeft : LucideIcons.menu,
          color: const Color(0xFF0F172A),
          size: 22,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          if (widget.canNavigateBack && widget.onNavigateBack != null) {
            widget.onNavigateBack!();
          } else {
            widget.onMenuClick();
          }
        },
      ),
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
      actions: [
        ...widget.actions,
        ShadPopover(
          controller: _popoverController,
          popover: (_) => SizedBox(
            width: 268,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(routeIcon, size: 18, color: routeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '网络线路详情',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Text(
                  '当前线路: $routeTitle',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '物理地址: ${routeMgr.activeBaseUrl.isEmpty ? "未连接" : routeMgr.activeBaseUrl}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: routeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    routeBadge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: routeColor,
                    ),
                  ),
                ),
                if (routeMgr.probeStatusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    routeMgr.probeStatusMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: routeMgr.isProbing
                        ? null
                        : () async {
                            final ok = await routeMgr.trySwitchToIntranet();
                            if (!context.mounted) return;
                            CustomDialogs.showToast(
                              context,
                              ok ? '已连接家庭内网通道' : '家庭内网暂不可达',
                              description: routeMgr.probeStatusMessage,
                              isError: !ok,
                            );
                          },
                    leading: Icon(
                      routeMgr.isProbing
                          ? LucideIcons.loader
                          : LucideIcons.zap,
                      size: 14,
                    ),
                    child: Text(
                      routeMgr.isProbing ? '正在探测内网...' : '尝试连接内网通道',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          child: IconButton(
            tooltip: routeTitle,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: const EdgeInsets.all(6),
            onPressed: () {
              HapticFeedback.selectionClick();
              _popoverController.toggle();
            },
            icon: routeMgr.isProbing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primary,
                    ),
                  )
                : Icon(routeIcon, color: routeColor, size: 20),
          ),
        ),
        if (widget.onSyncPressed != null)
          _CloudSyncActionButton(
            isManualSyncing: _isManualSyncing,
            primaryColor: theme.primary,
            onPressed: _handleSyncTap,
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _CloudSyncActionButton extends StatelessWidget {
  final bool isManualSyncing;
  final Color primaryColor;
  final VoidCallback onPressed;

  const _CloudSyncActionButton({
    required this.isManualSyncing,
    required this.primaryColor,
    required this.onPressed,
  });

  static const Color _amberColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineSyncService.instance,
      builder: (context, _) {
        final drafts = OfflineSyncService.instance.drafts;
        final isSyncing =
            isManualSyncing || OfflineSyncService.instance.isSyncing;
        final hasAlert = drafts.any(
          (d) => d.status == 'conflict' || d.status == 'failed',
        );
        final count = drafts.length;

        final String tooltip = isSyncing
            ? '正在同步...'
            : hasAlert
                ? '存在异常离线草稿 ($count)，点击处理'
                : count > 0
                    ? '待同步离线草稿: $count'
                    : '即时同步';

        return IconButton(
          tooltip: tooltip,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          padding: const EdgeInsets.all(6),
          onPressed: isSyncing ? null : onPressed,
          icon: isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _amberColor,
                  ),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      LucideIcons.cloud,
                      color: _amberColor,
                      size: 22,
                    ),
                    if (count > 0)
                      Positioned(
                        right: -7,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _amberColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

