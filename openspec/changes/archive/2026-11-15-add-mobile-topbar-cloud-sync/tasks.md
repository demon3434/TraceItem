# Tasks

## 1. 抽离并复用半屏草稿管理抽屉组件

- [x] 1.1 将 `mobile/lib/widgets/offline_outbox_banner.dart` 中的草稿列表与冲突仲裁半屏抽屉拆分为独立组件或公开静态入口 `OfflineOutboxBanner.showDraftsSheet(BuildContext)`（基于 `CustomDialogs.showModalSheet` 与 `ShadSheet`，遵循主题 Token 且零原生弹窗），确保拆分后单文件行数均严格低于 500 行；通过 `flutter analyze` 检查无编译或静态分析告警。

## 2. 顶栏常驻轻量云朵按钮与状态渲染

- [x] 2.1 在 `mobile/lib/widgets/main_top_bar.dart` 中新增 `Future<void> Function()? onSyncPressed` 回调参数，并在 `actions` 中（网络线路图标右侧）集成基于 `ListenableBuilder(listenable: OfflineSyncService.instance)` 驱动的轻量云朵按钮：实现空闲已同步（低饱和度 `LucideIcons.cloudCheck`）、有 `pending` 草稿（主题主色云朵 + 数字徽章）、有 `failed`/`conflict` 草稿（警示色云朵 + 徽章）及 `isSyncing` 进度圈 4 种状态，并适配 360dp 窄屏间距；通过 `flutter analyze` 与组件单测验证 4 种状态渲染及单文件 <500 行。

## 3. 全局双向同步调度与切网时序对齐

- [x] 3.1 公开 `mobile/lib/screens/category_manage_screen.dart` 的 `CategoryManageScreenState` 与 `loadCategories()` 方法，并在 `mobile/lib/screens/main_shell_screen.dart` 中挂载 `_categoryKey`，为跨页全局刷新提供统一入口；通过 `flutter analyze` 验证编译通过。
- [x] 3.2 在 `mobile/lib/screens/main_shell_screen.dart` 中实现 `_handleGlobalCloudSync()` 并传给 `MainTopBar.onSyncPressed`：存在 `failed`/`conflict` 草稿时直接弹出 `ShadSheet` 草稿抽屉；否则先确认或探测路由，离线时通过 `CustomDialogs.showToast` 提示等待联网，在线时依次执行 `OfflineSyncService.instance.syncCurrentUser(includeFailed: true)` 与当前激活页面数据刷新（首页/空间/分类）并弹出结果 Toast；编写交互验证用例或通过真机/模拟器实测各分支提示准确。
- [x] 3.3 对齐 `MainShellScreen` 的 `_connSub` 网络变更监听逻辑，将直接裸调 `syncCurrentUser()` 改为复用先等待 `NetworkRouteManager.instance.detectAndSwitchBestRoute()` 收敛路由后再触发 Outbox 同步的流程；通过 `flutter test` 验证路由切换与同步触发顺序测试通过。

## 4. 整体验证与规范检查

- [x] 4.1 执行 `flutter analyze`、`flutter test` 与所有修改文件行数核查（确认均 <500 行），并按 `AGENTS.md` 规范执行 `flutter build apk --release --target-platform android-arm64`（仅 ARMv8）确认可正常打包构建。

## 5. 首页首屏先显缓存与静默刷新 (SWR)

- [x] 5.1 在 `mobile/lib/screens/home_screen.dart` 中实现本地快照预热（读取 `MetaSnapshotStore` 与 `OfflineDb.getCachedItems`）与 `loadInitialData({bool keepSelection = false, bool silent = false})` 静默刷新模式：命中缓存时立即渲染列表且不显示全屏阻塞 Loading，静默刷新保留用户当前选中的房屋/房间/分类与搜索词；确保单文件行数严格 <500 行，通过 `flutter analyze` 检查。
- [x] 5.2 在 `mobile/lib/screens/main_shell_screen.dart` 与 `HomeScreen` 之间衔接冷启动路由收敛后的静默刷新流程，避免冷启动网络请求在路由未定前抢跑打向旧内网；补充 `flutter test` 单测验证“命中本地缓存优先上屏 + 后台静默刷新无感更新”逻辑。
- [x] 5.3 重新执行 `flutter analyze`、`flutter test` 与所有修改文件行数核查（确认均 <500 行），并按 `AGENTS.md` 规范执行 `flutter build apk --release --target-platform android-arm64` 验证 Release 构建通过。
