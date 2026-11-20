## Why

当前 Flutter 移动端存在严重的交互与功能缺陷：`HomeScreen` 顶部导航栏直接堆砌了房间管理、服务器配置、分类管理与退出登录按钮，页面极为凌乱；缺少房屋增删改、物品分类选择、多图与短视频录入、物品删除及独立全屏详情页；硬编码默认账号与媒体 URL；且缺少多巴胺主题系统及内外网双路由切换与局域网自动发现能力。本次参考 NutHollow 的左侧滑出抽屉架构，针对手机竖屏小屏进行现代化重构，并将「用户业务数据」与「软件系统设置」彻底分离，在非 Admin 家庭成员场景下实现与 Web 端对齐的完整生产级体验。

## What Changes

- **左侧抽屉菜单与统一顶栏导航**：移除拥挤的顶栏按钮集群，构建全局 `MainTopBar`（一级页显示 `☰` 唤出抽屉，二级子页自动变为 `←` 返回；右侧提供路由器/地球/断网线路状态图标与上下文操作）与左侧滑出 `MainDrawerContent`（顶部个人名片 + 右上角 `⚙️` 齿轮直达系统设置；菜单项承载「物品寻宝」「登记收纳」「房屋与房间管理」「物品分类管理」）。现阶段拦截 `admin` 账号登录并以 `ShadDialog` 引导使用 Web 端，同时在架构上保留角色扩展位。
- **房屋、房间与分类完整生命周期管理**：补齐移动端缺失的房屋 API（`createHouse`、`updateHouse`、`deleteHouse`）、`getItemDetail`、`register`、`updateMe`。新增独立 `SpaceManageScreen`（房屋与房间完整 CRUD，严格区分房屋建筑与房间功能 Emoji 图腾，危险删除统一弹出 `ShadDialog` 确认）与 `CategoryManageScreen`（作为用户业务数据放在主抽屉菜单，支持新建、改名换图标、排序、启停与安全解绑删除）。
- **独立物品详情页与全模态编辑页升级**：用全屏 `ItemDetailScreen` 替代局促的 `MediaPreviewDialog` 弹窗，支持多图浏览与双指缩放、音视频播放、完整位置路径与标签展示，以及底部常驻「编辑」「删除」操作栏；升级 `ItemEditScreen`，补齐物品分类选择、多张现场照片增删、15 秒寻路短视频采集/选取、60 秒语音备忘录与标签智能联想（`/items/tags/suggest`）；在首页 `HomeScreen` 补齐「全部空间 / 切换房屋」与分类筛选。
- **纯净登录与受控公开注册界面**：移除 `alice/bob/admin` 快捷体验按钮与默认填充账号密码；在登录页接入 `GET /api/auth/config`，根据 `allow_public_registration` 动态显示「账号登录 / 注册新账号」Tab 及完整注册操作表单；底部提供双态服务器配置入口卡片。
- **纯粹的软件设置二级菜单栈与 7 套多巴胺主题**：新增分层式 `SettingsScreen`（仅容纳软件与账号自身设置，不混入业务数据），包含个人资料与改密（`PUT /api/auth/me`）、内外网双地址配置与 mDNS 发现、7 套多巴胺主题配色（1:1 对齐 Web `theme.ts` 7 套多巴胺色板并持久化）、缓存清理与 `ShadDialog` 退出确认。
- **端到端内外网双路切换与 mDNS 局域网发现**：
  - **后端 (`server/`)**：兼容暴露 `GET /api/health` 与 `GET /health`；新增基于 `AsyncZeroconf` 的 `_traceitem._tcp.local.` mDNS 广播服务（支持容器桥接 IP 过滤与 `SERVICE_ADVERTISE_HOST` / `SERVICE_ADVERTISE_PORT` 配置），并配套宿主机 Avahi 反射脚本与部署指引。
  - **移动端 (`mobile/`)**：实现 `NetworkRouteManager`（蜂窝网络 0ms 快轨直连外网、WiFi 1.2s 双轨并发竞速内网优先、请求故障自动降级外网）与 Flutter mDNS 扫描（`_traceitem._tcp`），并消除 `MobileItemCard` 硬编码 `defaultBaseUrl` 拼图缺陷。
- **全面遵循 `shadcn_ui` 与排版红线**：所有弹窗、底部抽屉、气泡浮层与提示统一使用 `ShadDialog`、`ShadSheet`、`ShadPopover`、`ShadToaster` 及 `LucideIcons`，严禁原生 `alert`/`confirm`/`SnackBar`，全端字号 `>= 12px`，单文件代码行数严格 `< 500` 行。

## Capabilities

### New Capabilities
- `mobile-navigation-and-spaces`: 移动端左侧抽屉菜单、全局自适应顶栏、房屋/房间与分类完整生命周期页面、软件设置二级页栈以及基于 `shadcn_ui`（`ShadDialog`、`ShadSheet`、`ShadToaster`、`LucideIcons`）的 7 套多巴胺主题体系。
- `mobile-auth-and-lan-discovery`: 纯净账密登录与 `/api/auth/config` 受控公开注册流程、内外网双路由智能选线与故障降级、以及后端与移动端端到端的 `_traceitem._tcp.local.` mDNS 局域网自动发现能力。

### Modified Capabilities
- `mobile-media-and-performance`: 将弹窗式媒体预览升级为全屏 `ItemDetailScreen`（保留手势缩放与音视频播放并增加编辑/删除操作），扩展 `ItemEditScreen` 支持多图、15 秒短视频、分类与标签联想，并将全部媒体 URL 改为跟随当前激活路由动态解析。

## Impact

- **移动端 (`mobile/`)**：`pubspec.yaml`（新增 mDNS 与网络状态监听依赖）、`AndroidManifest.xml` 与 `Info.plist`（组播与本地网络权限）、`lib/main.dart`、`lib/core/`（`api_service.dart`、`network_route_manager.dart`、`lan_discovery_service.dart`、`theme_controller.dart`）、`lib/screens/`（主壳层、登录注册、首页、物品详情/编辑、空间管理、分类管理、设置及子页面）、`lib/widgets/`（抽屉、顶栏、线路浮层、统一 `ShadDialog`/`ShadSheet` 组件）。
- **后端 (`server/`)**：`requirements.txt`（新增 `zeroconf`）、`app/main.py`（`lifespan` 集成 mDNS 广播与 `/api/health` 路由）、`app/services/mdns_discovery.py`。
- **部署与脚本**：`docker-compose.yml`（新增 `SERVICE_ADVERTISE_HOST` / `SERVICE_ADVERTISE_PORT` 与可选 mDNS 网桥配置）、`scripts/setup_avahi_traceitem.sh` 与局域网发现文档。
