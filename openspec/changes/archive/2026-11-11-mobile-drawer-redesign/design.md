## Context

背景与动机见 [proposal.md](proposal.md)，行为契约见 `specs/`。当前实现存在以下工程瓶颈：
- `mobile/lib/screens/home_screen.dart` 单文件已达 `495` 行（逼近 `500` 行硬性上限），把导航、设置、空间过滤、物品网格耦合在同一文件内；
- `mobile/lib/core/api_service.dart` 缺少房屋增删改、物品详情、公开注册、个人资料修改等接口封装；
- `mobile/lib/widgets/item_card.dart` 使用硬编码 `AppConstants.defaultBaseUrl` 拼接缩略图，且与媒体播放器均未接入动态路由；
- `server/app/main.py` 仅挂载 `/health` 根路由，缺少 `/api/health` 兼容及 mDNS 广播服务。

所有新增与重构代码必须遵守：Flutter 端全面采用 `shadcn_ui`（`ShadDialog`、`ShadSheet`、`ShadPopover`、`ShadToaster`、`LucideIcons`），杜绝原生 `alert`/`confirm`/`SnackBar`，全端字号 `>= 12px`，单文件代码行数严格 `< 500` 行。

## Goals / Non-Goals

**Goals:**
- 构建 `MainShellScreen` + `MainTopBar` + 左侧 `MainDrawerContent` 的模块化导航壳层，确保每个文件职责单一且控制在 `400` 行以内。
- 严格区分 **用户业务数据**（抽屉一级菜单：物品寻宝、登记收纳、房屋与房间管理、物品分类管理）与 **软件/账号设置**（抽屉右上角齿轮入口：`SettingsScreen` 二级页栈）。
- 对标 NutHollow 实现 `NetworkRouteManager` 双路由自适应切换与前后端 `_traceitem._tcp.local.` mDNS 自动发现。
- 实现 Web 端同源的 7 套多巴胺主题动态换肤与持久化，以及纯净账密登录 + 受控公开注册界面。

**Non-Goals:**
- 本期不实现手机端 Admin 管理工作台（用户治理、上帝视角、TAR 备份、存储清理仍保留在 Web 端，仅预留角色扩展接口）。
- 本期不引入手机端离线 SQLite 记账队列（保持在线请求 + 内外网自动容灾切换架构）。
- 本期不引入 Web 端其余 11 套 `shadcn` 经典单色调色盘，聚焦 7 套多巴胺活力主题。

## Decisions

### 1. 左侧抽屉导航壳层与返回栈协调
- **决策**：引入 `MainShellScreen` 持有 `Scaffold(drawer: ...)`、`MainTopBar` 与 `MobileDestination` 枚举（`itemsHome`、`quickAdd`、`spaceManage`、`categoryManage`、`settings`），并在进入 `ItemDetailScreen`、`ItemEditScreen` 及 `SettingsScreen` 内部子页面时通知顶栏将左侧 `Menu` 图标切换为 `ArrowBack`。
- **理由**：复刻 NutHollow 竖屏高屏效布局，将有限屏幕空间留给物品照片与房间胶囊；二级页栈通过 `PopScope` 与顶栏返回按钮联动，操作符合移动端直觉。
- **备选方案**：底部 3/4 Tab 导航。因用户明确指定参考 NutHollow 左侧栏唤出菜单设计而放弃。

### 2. 业务数据菜单与软件设置中心严格隔离
- **决策**：`MainDrawerContent` 菜单列表仅放置「物品寻宝」「登记收纳」「房屋与房间管理」「物品分类管理」；抽屉顶部名片右上角齿轮按钮专门进入 `SettingsScreen`（含个人资料/改密、内外网地址与发现、7 套多巴胺主题、缓存清理与退出登录）。
- **理由**：分类属于用户的私有收纳数据字典，不应混在软件设置菜单中；同时抽屉支持按 `role` 条件装配菜单，为未来扩展手机端 Admin 留出清晰接缝。

### 3. 基于 `ChangeNotifier` 的 7 套多巴胺主题驱动
- **决策**：新建 `mobile/lib/core/theme_controller.dart`，完整映射 Web `theme.ts` 的 7 套多巴胺色板（`warm-orange`、`strawberry-sweet`、`mint-lemon`、`starry-castle`、`elegant-wood`、`lavender-dream`、`cyber-neon`），通过 `SharedPreferences` 持久化并驱动 `ShadThemeData`、背景奶彩色、渐变按钮与双层漫反射投影。
- **理由**：彻底消除页面中硬编码 `AppConstants.dopamineOrange`，确保切换主题后全 App 无需重启即刻焕新。

### 4. 双路智能选线 (`NetworkRouteManager`) 与动态媒体解析
- **决策**：在本地持久化 `intranet_url` 与 `extranet_url`，通过 `connectivity_plus` 监听网络切换并挂载 Dio 错误容灾拦截器：
  - 蜂窝移动网络 + 内网为私网 IP -> `0ms` 快轨直连 `extranet_url`；
  - WiFi / 以太网 -> 并发竞速探测（内网 `1.2s` 超时优先、外网 `1.5s` 兜底，探测顺序优先请求 `/api/health` 并兼容 `/health`）；
  - 内网业务请求连接超时 -> 自动容灾切换至 `extranet_url` 并刷新状态提示；
  - 统一由 `ApiService.resolveMediaUrl(String? path)` 基于当前活跃 `baseUrl` 解析图片、缩略图与音视频 URL。
- **理由**：解决传统单 URL 模式下回家/出门切换网络后图片裂图与请求卡死问题。

### 5. 端到端 mDNS 局域网服务发现 (`_traceitem._tcp.local.`)
- **决策**：
  - **后端 (`server/app/services/mdns_discovery.py`)**：引入 `zeroconf`，在 FastAPI `lifespan` 启动 `AsyncZeroconf` 广播 `_traceitem._tcp.local.`；探测宿主机局域网 IP 时在容器环境自动过滤 `172.x` 网桥地址，并优先读取 `SERVICE_ADVERTISE_HOST` 与 `SERVICE_ADVERTISE_PORT`（Docker 默认映射 `8085`）；同时在 `server/app/main.py` 补充 `GET /api/health`。
  - **移动端 (`mobile/lib/core/lan_discovery_service.dart`)**：集成 Flutter mDNS 插件（`nsd` 或 `bonsoir`）扫描 `_traceitem._tcp`，在 Android `AndroidManifest.xml` 声明 `CHANGE_WIFI_MULTICAST_STATE` / `ACCESS_WIFI_STATE` / `ACCESS_NETWORK_STATE`，在 iOS `Info.plist` 声明 `NSLocalNetworkUsageDescription` 与 `NSBonjourServices`（`_traceitem._tcp`）。
  - **容器部署配套**：提供 `scripts/setup_avahi_traceitem.sh` 与 `docs/mdns_lan_discovery_guide.md`，在 `docker-compose.yml` 中增加通告环境变量与可选 Avahi 反射网桥配置。
- **理由**：与 NutHollow 工业实践一致，保证 Docker 部署的家庭 NAS 也能在 1 秒内被同 WiFi 下的手机端自动发现。

### 6. 纯净登录与受控公开注册
- **决策**：移除 `LoginScreen` 中的快捷测试账号按钮与默认账号密码；进入登录页及修改服务地址后主动调用 `GET /api/auth/config`，依据 `allow_public_registration` 控制注册 Tab 显隐；对 `admin` 账号登录使用 `ShadDialog` 友善拦截。
- **理由**：消除生产环境硬编码测试账号隐患，并与 Web 端公开注册开关语义保持 100% 一致。

## Risks / Trade-offs

- **[风险] Docker 默认桥接网络隔离 mDNS 组播包** -> 缓解：后端支持通过 `SERVICE_ADVERTISE_HOST`/`SERVICE_ADVERTISE_PORT` 显式通告，并提供 `scripts/setup_avahi_traceitem.sh` 开启宿主机 `avahi-daemon` 反射器（`enable-reflector=yes`），同时保留手动输入与局域网检测兜底。
- **[风险] Flutter Material `Drawer` 与 `shadcn_ui` 视觉风格割裂** -> 缓解：抽屉、顶栏、卡片与表单全部绑定 `ThemeController` 色板与 Squircle 圆角规范，所有弹窗/抽屉/气泡/提示严格使用 `ShadDialog`/`ShadSheet`/`ShadPopover`/`ShadToaster`。
- **[风险] 功能大面积补齐导致单文件超过 500 行** -> 缓解：将媒体上传区、标签自动联想、房屋房间表单、设置子页面全部拆分为独立 Widget/Screen 文件，并在收尾阶段执行全量行数核查。
