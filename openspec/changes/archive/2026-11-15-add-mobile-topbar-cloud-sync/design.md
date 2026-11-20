# Design

## Context

详见 `proposal.md - Why`。当前移动端在 `MainTopBar` 右侧已实现网络线路指示器与 `ShadPopover` 探测面板，`MainShellScreen` 通过 `WidgetsBindingObserver` 和 `Connectivity` 实现事件驱动自动同步（零后台轮询），`OfflineOutboxBanner` 则在首页顶部承担待同步草稿展示与 `ShadSheet` 管理抽屉入口。

受限于单文件 <500 行、禁止原生弹窗、以及 360dp 窄屏顶栏防拥挤等工程约束，本设计需要以最小侵入方式将双向同步能力与异常直达能力提升至全局顶栏，并消除切网时的路由探测竞态。

## Goals / Non-Goals

**Goals:**
- 在 `MainTopBar` 右侧增加常驻轻量云朵按钮，完全基于 `ListenableBuilder` / 现有 `ChangeNotifier` 事件驱动更新，保持零后台定时器轮询与零常驻算力开销。
- 复用现有 `OfflineOutboxBanner` 的 `ShadSheet` 草稿管理抽屉，避免重复实现两套草稿 UI。
- 支持在「物品寻宝」「空间管理」「分类管理」「系统设置」等任意一级页面点击云朵完成“推草稿 + 拉远端最新数据 + 刷新当前页 + Toast 反馈”。
- 对齐 `MainShellScreen` 切网时“先路由收敛、再同步 Outbox”的执行顺序。

**Non-Goals:**
- 不引入任何周期性后台轮询（如 `Timer.periodic` 或常驻 `WorkManager` 轮询）。
- 不修改后端接口、不新增数据库表或改变现有 Outbox 幂等/冲突仲裁协议。
- 不移除首页现有的 `OfflineOutboxBanner`（保留其作为首页大卡片提示，与顶栏云朵形成“全局入口 + 首页详情”互补）。

## Decisions

1. **云朵状态监听方式：直接复用 `OfflineSyncService.instance` (`ChangeNotifier`)**
   - **决策**：在 `MainTopBar` 内通过 `ListenableBuilder(listenable: OfflineSyncService.instance, ...)`（或同步接入 `_onRouteChanged`）驱动云朵图标与徽章重绘，不新增独立的状态管理类。
   - **理由**：`OfflineSyncService` 已维护 `drafts` 与 `isSyncing` 并主动 `notifyListeners()`，复用它可保持单一数据源且代码量极少。
   - **备选方案**：在 `MainShellScreen` 中手动传递 `isSyncing` / `draftCount` 参数给 `MainTopBar`。未采用原因：会增加 `MainShellScreen` 样板代码与 `setState` 范围。

2. **草稿管理抽屉复用：将 `_showDraftsSheet` 抽离/公开为可复用方法**
   - **决策**：将 `offline_outbox_banner.dart`（当前 444 行）中的 `_showDraftsSheet(BuildContext)` 暴露为 `OfflineOutboxBanner.showDraftsSheet(BuildContext)`，或将半屏抽屉内容拆分为独立文件 `offline_outbox_sheet.dart`，确保每个文件严格控制在 300~400 行以内（远低于 500 行红线）。
   - **理由**：顶栏云朵在检测到 `failed` / `conflict` 草稿时直接调用同一抽屉，保证交互、样式与仲裁逻辑 100% 一致。

3. **双向同步的“拉取刷新”调度：由 `MainShellScreen` 统一派发当前页刷新回调**
   - **决策**：`MainTopBar` 接收可选的 `Future<void> Function()? onSyncPressed`（或由 `MainShellScreen` 传入 `_handleGlobalCloudSync`）。当无异常草稿触发同步时：
     1. 若当前处于离线/未配置状态且无本地探测成功，先尝试 `NetworkRouteManager.instance.detectAndSwitchBestRoute()`；
     2. 若有 `pending` 草稿，调用 `OfflineSyncService.instance.syncCurrentUser(includeFailed: true)`；
     3. 无论是否有草稿，均按 `_currentDestination` 刷新当前页数据：
        - `itemsHome` -> `_homeKey.currentState?.loadInitialData(keepSelection: true)`
        - `spaceManage` -> `_spaceKey.currentState?.loadSpaces()`
        - `categoryManage` -> `_categoryKey.currentState?.loadCategories()`（将 `_CategoryManageScreenState` 公开为 `CategoryManageScreenState` 并暴露 `loadCategories()`）
     4. 通过 `CustomDialogs.showToast` 反馈同步与刷新结果。
   - **备选方案**：仅在 `HomeScreen` 刷新。未采用原因：无法解决用户在 Web 端修改空间/分类后，停留在手机端「空间管理」「分类管理」页面无法一键刷新的核心痛点。

4. **切网自动同步竞态治理：合并至路由收敛之后**
   - **决策**：移除 `MainShellScreen` 中 `_connSub` 直接裸调 `OfflineSyncService.instance.syncCurrentUser()` 的逻辑，改为先执行 `_recalibrateRouteAndRefresh(refreshIfLongPause: false)`（内部先 `await routeMgr.detectAndSwitchBestRoute()`，再 `syncCurrentUser()`），并复用 `NetworkRouteManager` 的并发去重（`_inflightProbe`）。
   - **理由**：彻底消除 Wi-Fi 切 5G 瞬间用内网旧地址发请求导致草稿误标 `failed` 的问题。

5. **360dp 窄屏顶栏空间与参考样式对齐**
   - **决策**：云朵图标对齐参考项目 NutHollow 样式，统一采用琥珀色（`#F59E0B`）`LucideIcons.cloud`（`22px`）+ 紧凑 `BoxConstraints(minWidth: 38, minHeight: 38)`，同步中切换为 `20×20` 琥珀色 `CircularProgressIndicator`，有待传/异常草稿时叠加琥珀底黑字数字胶囊徽章，确保「空间管理」带 `+` 号时标题仍清晰可读。

6. **首页首屏 SWR（Stale-While-Revalidate）加载策略与路由收敛配合**
   - **决策**：
     1. **先显缓存**：`HomeScreen.initState()` 先执行本地缓存预热 `_hydrateFromLocalCache()`，从 `MetaSnapshotStore.loadSnapshot(uid)` 与 `OfflineDb.getCachedItems(...)` 读取当前用户数据；若命中任意缓存（房屋/分类/物品），立即 `setState` 渲染且不置 `_loading = true`（仅首次无缓存时展示全屏加载态）。
     2. **后静默刷新**：`loadInitialData({bool keepSelection = false, bool silent = false})` 新增 `silent` 参数；`silent == true` 时不置 `_loading = true` 遮挡界面，并保留用户当前已选的 `_activeHouse` / `_activeRoom` / `_selectedCategory` 与搜索词。
     3. **错峰配合路由收敛**：冷启动时由 `MainShellScreen._recalibrateRouteAndRefresh` 在 `NetworkRouteManager.detectAndSwitchBestRoute()` 收敛后以 `silent: true` 触发远端拉取（同时 `NetworkRouteManager.checkUrlHealthy` 对连接不可达快速失败且内网超时降至 `600ms`），避免首屏网络请求在路由未定前抢跑打向旧内网。
   - **备选方案**：在 `HomeScreen.initState()` 中阻塞等待路由探测后再读缓存。未采用原因：仍会让用户在公网环境下看到首屏转圈。

## Risks / Trade-offs

- **[Risk] 用户在无网状态下点击云朵按钮触发同步** → **Mitigation**: 若 `NetworkRouteManager.instance.isOffline` 或探测后仍不可达，跳过拉取并在 `CustomDialogs.showToast` 中提示「当前处于离线状态，草稿将在联网后自动同步」（有 `failed`/`conflict` 时仍允许打开本地草稿抽屉管理）。
- **[Risk] 静默刷新返回时覆盖用户刚在缓存页面切换的筛选条件** → **Mitigation**: `loadInitialData(keepSelection: true, silent: true)` 在刷新 `_houses` / `_rooms` / `_categories` 后保留当前选中的 ID 引用，并按当前筛选条件与搜索词拉取 `_items`，避免列表跳回默认房屋或丢失搜索词。
- **[Risk] 单文件行数逼近 500 行红线** → **Mitigation**: `offline_outbox_banner.dart` 目前已有 444 行，若改动触及其内部逻辑，优先将半屏抽屉拆出为 `mobile/lib/widgets/offline_outbox_sheet.dart`；同时监控 `main_top_bar.dart`、`main_shell_screen.dart` 与 `home_screen.dart` 修改后均严格低于 500 行。

