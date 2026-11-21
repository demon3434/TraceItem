import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/navigation_models.dart';
import '../core/network_route_manager.dart';
import '../core/offline_sync_service.dart';
import '../core/theme_controller.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/main_drawer_content.dart';
import '../widgets/main_top_bar.dart';
import '../widgets/offline_outbox_banner.dart';
import 'category_manage_screen.dart';
import 'home_screen.dart';
import 'item_edit_screen.dart';
import 'login_screen.dart';
import 'settings/settings_screen.dart';
import 'space_manage_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<SpaceManageScreenState> _spaceKey =
      GlobalKey<SpaceManageScreenState>();
  final GlobalKey<CategoryManageScreenState> _categoryKey =
      GlobalKey<CategoryManageScreenState>();

  MobileDestination _currentDestination = MobileDestination.itemsHome;
  SubLevelState? _activeSubLevel;
  DateTime? _lastPausedAt;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.instance.onUnauthorized = _handleSessionExpired;
    ApiService.instance.onServerInstanceChanged = _handleServerInstanceChanged;
    NetworkRouteManager.instance.startAutoRouting();
    _recalibrateRouteAndRefresh(
      refreshIfLongPause: false,
      forceSilentHomeRefresh: true,
    );
    ThemeController.instance.addListener(_onThemeChanged);
    OfflineSyncService.instance.onSyncedItems = () {
      _homeKey.currentState?.loadInitialData(keepSelection: true);
    };
    OfflineSyncService.instance.refreshDrafts();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) {
        _recalibrateRouteAndRefresh(refreshIfLongPause: false);
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    if (OfflineSyncService.instance.onSyncedItems != null) {
      OfflineSyncService.instance.onSyncedItems = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    if (ApiService.instance.onUnauthorized == _handleSessionExpired) {
      ApiService.instance.onUnauthorized = null;
    }
    if (ApiService.instance.onServerInstanceChanged ==
        _handleServerInstanceChanged) {
      ApiService.instance.onServerInstanceChanged = null;
    }
    ThemeController.instance.removeListener(_onThemeChanged);
    NetworkRouteManager.instance.stopAutoRouting();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _lastPausedAt;
      _lastPausedAt = null;
      final isLongPause = pausedAt != null &&
          DateTime.now().difference(pausedAt) >= const Duration(minutes: 5);
      _recalibrateRouteAndRefresh(refreshIfLongPause: isLongPause);
    }
  }

  Future<void> _recalibrateRouteAndRefresh({
    required bool refreshIfLongPause,
    bool forceSilentHomeRefresh = false,
  }) async {
    final routeMgr = NetworkRouteManager.instance;
    final previousBase = routeMgr.activeBaseUrl;
    final nextBase = await routeMgr.detectAndSwitchBestRoute();
    if (!mounted) return;
    if (forceSilentHomeRefresh ||
        nextBase != previousBase ||
        refreshIfLongPause) {
      await _homeKey.currentState?.loadInitialData(
        keepSelection: true,
        silent: true,
      );
    }
    await OfflineSyncService.instance.syncCurrentUser();
  }

  Future<void> _handleGlobalCloudSync() async {
    final drafts = OfflineSyncService.instance.drafts;
    final hasAlert = drafts.any(
      (d) => d.status == 'conflict' || d.status == 'failed',
    );
    if (hasAlert) {
      await OfflineOutboxBanner.showDraftsSheet(context);
      return;
    }

    final routeMgr = NetworkRouteManager.instance;
    if (routeMgr.isOffline || routeMgr.activeBaseUrl.isEmpty) {
      await routeMgr.detectAndSwitchBestRoute();
    }
    if (!mounted) return;
    if (routeMgr.isOffline || routeMgr.activeBaseUrl.isEmpty) {
      CustomDialogs.showToast(
        context,
        '当前处于离线状态',
        description: '离线草稿将在联网后自动同步',
        isError: true,
      );
      return;
    }

    final syncedCount = await OfflineSyncService.instance.syncCurrentUser(
      includeFailed: true,
    );
    await _refreshCurrentDestinationData();
    if (!mounted) return;

    final remaining = OfflineSyncService.instance.drafts;
    final nowHasAlert = remaining.any(
      (d) => d.status == 'conflict' || d.status == 'failed',
    );
    if (nowHasAlert) {
      CustomDialogs.showToast(
        context,
        '部分草稿同步异常',
        description: '请查看待同步草稿列表处理',
        isError: true,
      );
      await OfflineOutboxBanner.showDraftsSheet(context);
    } else if (syncedCount > 0) {
      CustomDialogs.showToast(context, '已同步 $syncedCount 件物品并刷新');
    } else {
      CustomDialogs.showToast(context, '已与云端保持最新');
    }
  }

  Future<void> _refreshCurrentDestinationData() async {
    switch (_currentDestination) {
      case MobileDestination.itemsHome:
        await _homeKey.currentState?.loadInitialData(keepSelection: true);
      case MobileDestination.spaceManage:
        await _spaceKey.currentState?.loadSpaces();
      case MobileDestination.categoryManage:
        await _categoryKey.currentState?.loadCategories();
      case MobileDestination.quickAdd:
      case MobileDestination.settings:
        await _homeKey.currentState?.loadInitialData(keepSelection: true);
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    CustomDialogs.showToast(
      context,
      '登录状态已过期',
      description: '请重新登录家庭账本账号',
      isError: true,
    );
    _handleLoggedOut();
  }

  void _handleServerInstanceChanged() {
    if (!mounted) return;
    CustomDialogs.showToast(
      context,
      '检测到连接至新的家庭账本服务',
      description: '已重置本地工作区，请重新登录',
    );
    _handleLoggedOut();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _selectDestination(MobileDestination dest) {
    if (_currentDestination == dest && _activeSubLevel == null) return;
    setState(() {
      _activeSubLevel = null;
      _currentDestination = dest;
    });
  }

  void _handleLoggedOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  List<Widget> _buildDestinationActions() {
    if (_activeSubLevel != null) return _activeSubLevel!.actions;
    if (_currentDestination == MobileDestination.spaceManage) {
      return [
        IconButton(
          tooltip: '新建房屋',
          icon: Icon(
            LucideIcons.plus,
            color: ThemeController.instance.current.primary,
            size: 22,
          ),
          onPressed: () => _spaceKey.currentState?.openCreateHouse(),
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final user = ApiService.instance.currentUser;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final topTitle = _activeSubLevel?.title ??
        '${_currentDestination.title} ${_currentDestination.emoji}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (_activeSubLevel != null) {
          _activeSubLevel!.onBack();
        } else if (_currentDestination != MobileDestination.itemsHome) {
          _selectDestination(MobileDestination.itemsHome);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.pageBg,
        // 避开 Android 全面屏边缘系统返回手势区，提供宽阔的左侧滑入跟手触发区
        drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.25,
        drawerEnableOpenDragGesture: _activeSubLevel == null,
        drawer: MainDrawerContent(
          user: user,
          currentDestination: _currentDestination,
          onSelectDestination: _selectDestination,
          onNavigateToSettings: () =>
              _selectDestination(MobileDestination.settings),
          onCloseDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        appBar: MainTopBar(
          title: topTitle,
          canNavigateBack: _activeSubLevel != null,
          onMenuClick: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateBack: () => _activeSubLevel?.onBack(),
          onSyncPressed: _handleGlobalCloudSync,
          actions: _buildDestinationActions(),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (_activeSubLevel != null) return;
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) return;
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 380) {
              HapticFeedback.selectionClick();
              _scaffoldKey.currentState?.openDrawer();
            }
          },
          child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_currentDestination) {
            MobileDestination.itemsHome => HomeScreen(
                key: _homeKey,
                deferInitialRemoteFetch: true,
                isKeyboardOpen: isKeyboardOpen,
              ),
            MobileDestination.quickAdd => ItemEditScreen(
                key: const ValueKey('quick_add_embedded'),
                embedded: true,
                onSavedEmbedded: () {
                  _selectDestination(MobileDestination.itemsHome);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _homeKey.currentState?.loadInitialData(keepSelection: true);
                  });
                },
              ),
            MobileDestination.spaceManage => SpaceManageScreen(
                key: _spaceKey,
                onBrowseSpace: (house, room) {
                  _selectDestination(MobileDestination.itemsHome);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _homeKey.currentState?.applySpaceFilter(house, room);
                  });
                },
                onDataUpdated: () =>
                    _homeKey.currentState?.loadInitialData(keepSelection: true),
              ),
            MobileDestination.categoryManage => CategoryManageScreen(
                key: _categoryKey,
                onDataUpdated: () =>
                    _homeKey.currentState?.loadInitialData(keepSelection: true),
              ),
            MobileDestination.settings => SettingsScreen(
                onSubLevelChange: (sub) {
                  if (mounted) setState(() => _activeSubLevel = sub);
                },
                onProfileUpdated: () {
                  if (mounted) setState(() {});
                },
                onLoggedOut: _handleLoggedOut,
              ),
          },
        ),
        ),
      ),
    );
  }
}
