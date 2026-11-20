# Proposal

## Why

当前移动端采用“系统事件驱动自动同步（零后台轮询）”与“首页局部 `OfflineOutboxBanner`”机制，存在两处真实体验缝隙：一是用户在电脑 Web 端或另一台手机修改空间、分类或物品后，短时间切回移动端（挂起不足 5 分钟且线路未变）或在「空间管理」「分类管理」等非首页页面停留时，缺少全局一键双向同步与刷新入口，也无法直观感知离线草稿与同步异常状态；二是在 `MainShellScreen` 中，系统网络变更事件直接触发 `OfflineSyncService.syncCurrentUser()`，未等待 `NetworkRouteManager` 完成内外网探测切换，切网瞬间存在请求打向旧不可达线路的竞态风险。

## What Changes

- **顶栏常驻轻量云朵同步按钮**：在 `MainTopBar` 右上角（网络线路图标旁）常驻轻量云朵图标按钮，严格零后台轮询，仅监听 `OfflineSyncService` 与 `NetworkRouteManager` 状态变化，样式对齐参考项目（NutHollow）：
  1. 空闲态：常驻琥珀色（`#F59E0B`）`LucideIcons.cloud`；
  2. 有待同步或异常草稿（`pending` / `failed` / `conflict`）：琥珀色云朵 + 琥珀底黑字数字徽章；
  3. 同步进行中：琥珀色微型进度圈并防重点击。
- **智能分流点击交互**：
  - 当存在 `failed` 或 `conflict` 草稿时，点击云朵直接唤起既有的半屏草稿管理抽屉（`ShadSheet`，由 `CustomDialogs.showModalSheet` 封装），在任意一级页面均可直达重试或冲突仲裁；
  - 当无失败/冲突草稿时，点击云朵执行“轻量双向同步”：先推送待上传 Outbox 草稿，再拉取最新房屋/房间/分类快照并刷新当前激活页面（首页、空间管理页或分类管理页），完成后通过 `CustomDialogs.showToast` 给予短时轻量气泡提示；全程严禁使用原生 `alert`/`confirm`。
- **切网与冷启动路由探测优化**：调整 `MainShellScreen` 网络恢复监听与冷启动时序，先等待 `NetworkRouteManager.detectAndSwitchBestRoute()` 完成线路收敛后再触发 `OfflineSyncService.instance.syncCurrentUser()`；同时优化 `NetworkRouteManager.checkUrlHealthy` 遇到连接不可达时立即快速失败并将内网探测超时缩减至 `600ms`。
- **首页首屏先显缓存、后静默刷新（SWR）**：冷启动或初始化进入首页时，优先从 `MetaSnapshotStore` 与本地 SQLite `OfflineDb.cached_items` 毫秒级渲染空间、分类与物品列表（有缓存时不阻塞转圈），待路由收敛后在后台静默拉取最新远端数据并无感更新界面。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mobile-sync-and-concurrency-guard`: 新增顶栏常驻轻量云朵双向同步入口、首页首屏 SWR（先显缓存后静默刷新）能力，并规范网络切换及冷启动“先收敛路由、再执行 Outbox 自动同步”的时序约束。

## Impact

- **移动端 UI 与导航壳层**：`mobile/lib/widgets/main_top_bar.dart`、`mobile/lib/screens/main_shell_screen.dart`、`mobile/lib/screens/home_screen.dart`、`mobile/lib/screens/category_manage_screen.dart`
- **移动端网络与路由层**：`mobile/lib/core/network_route_manager.dart`
- **移动端离线草稿抽屉复用**：`mobile/lib/widgets/offline_outbox_banner.dart`、`mobile/lib/widgets/offline_outbox_sheet.dart`（确保单文件严格 <500 行）
- **后端 / Web 端**：无接口变更，完全复用现有 `/api/houses`、`/api/rooms`、`/api/categories` 与 `/api/items` 服务端接口。

