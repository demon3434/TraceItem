# Spec Delta

## ADDED Requirements

### Requirement: 顶栏常驻轻量云朵双向同步入口
移动端主顶栏 SHALL 在右侧网络线路图标旁常驻轻量云朵同步按钮，通过事件监听（无后台轮询）实时展示空闲、待同步、失败/冲突及同步中四种状态，并提供全页面一键双向同步与草稿抽屉直达能力。

#### Scenario: 不同同步状态下的顶栏云朵视觉反馈
- **WHEN** 用户位于任意挂载主顶栏的页面且 `OfflineSyncService` 与 `NetworkRouteManager` 状态发生变化
- **THEN** 顶栏云朵按钮 SHALL 分别呈现：同步中显示琥珀色微型进度指示器并禁用重复点击；存在待同步或异常草稿（`pending` / `failed` / `conflict`）时显示琥珀色云朵（`#F59E0B`）与琥珀底黑字数字徽章；无草稿时显示琥珀色云朵图标

#### Scenario: 存在失败或冲突草稿时点击云朵直达半屏管理抽屉
- **WHEN** 本地存在至少一条 `failed` 或 `conflict` 状态的离线草稿，用户在任意一级页面点击顶栏云朵按钮
- **THEN** 客户端 SHALL 直接弹出统一设计的半屏草稿管理抽屉（`ShadSheet`），支持查看失败原因、立即重试或冲突仲裁，而不使用原生弹窗

#### Scenario: 无异常草稿时点击云朵执行双向同步与当前页刷新
- **WHEN** 本地不存在 `failed` 或 `conflict` 草稿，用户点击顶栏云朵按钮
- **THEN** 客户端 SHALL 先推送待同步的 Outbox 草稿（若有），再刷新当前激活页面对应的数据（首页物品与空间/分类快照、空间管理页或分类管理页），并通过 `CustomDialogs.showToast` 弹出短时提示反馈同步结果

### Requirement: 切网后先收敛路由再触发 Outbox 自动同步
移动端主壳层 SHALL 在网络连通性恢复或网络类型切换时，先等待内外网路由探测完成线路收敛，再触发 `OfflineSyncService` 自动上传待同步草稿。

#### Scenario: 从家庭 Wi-Fi 切换至蜂窝移动网络时避免误打旧内网
- **WHEN** 设备网络连接发生变化且系统触发 `Connectivity` 变更回调
- **THEN** 主壳层 SHALL 等待 `NetworkRouteManager.detectAndSwitchBestRoute()` 完成可用线路收敛后再调用 `OfflineSyncService.syncCurrentUser()`，避免在路由尚未切至外网时向不可达内网地址发起同步导致误标失败

### Requirement: 首页首屏先显缓存与后台静默刷新
移动端物品寻宝首页 SHALL 在冷启动或初始化加载时优先读取当前用户的本地元数据快照与 `cached_items` 立即渲染界面，并在后台路由收敛后静默拉取远端最新数据无感更新。

#### Scenario: 冷启动命中本地缓存时秒开渲染并后台静默刷新
- **WHEN** 已登录用户冷启动 App 进入物品寻宝首页且本地存在当前用户的空间快照或缓存物品
- **THEN** 首页 SHALL 立即渲染本地缓存的房屋、房间、分类及物品列表且不展示全屏阻塞加载态，随后在路由收敛后静默拉取远端最新数据并保留用户当前筛选态无感刷新列表

#### Scenario: 后台静默刷新遇离线或弱网时不覆盖已渲染缓存
- **WHEN** 首页已完成本地缓存首屏渲染，但后台静默刷新因离线或网络超时失败
- **THEN** 首页 SHALL 保持当前已渲染的本地缓存数据可见不被清空，仅通过 `CustomDialogs.showToast` 给出轻量提示

