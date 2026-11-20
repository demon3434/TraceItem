## 1. 后端健康检查兼容与 mDNS 局域网广播

- [x] 1.1 在 `server/requirements.txt` 新增 `zeroconf`，创建 `server/app/services/mdns_discovery.py` 实现 `AsyncZeroconf` 异步广播 `_traceitem._tcp.local.`（支持 `SERVICE_ADVERTISE_HOST`、`SERVICE_ADVERTISE_PORT` 及容器内 `172.x` 网桥 IP 过滤）并在 `server/app/main.py` 的 `lifespan` 中启停；编写单元测试验证 IP 过滤与服务注册逻辑通过。
- [x] 1.2 在 `server/app/main.py` 兼容挂载 `GET /api/health`（保留 `GET /health`），通过 `pytest` / FastAPI `TestClient` 验证两个健康检查接口均返回 HTTP 200 标准响应。
- [x] 1.3 更新 `docker-compose.yml` 补充 `SERVICE_ADVERTISE_HOST` / `SERVICE_ADVERTISE_PORT` 环境变量与可选 mDNS 网桥配置，新增 `scripts/setup_avahi_traceitem.sh` 与 `docs/mdns_lan_discovery_guide.md`；使用 `bash -n` 验证脚本语法无误。

## 2. 移动端基础架构、多巴胺主题与双路由网络引擎

- [x] 2.1 在 `mobile/pubspec.yaml` 引入 mDNS 发现插件（`nsd` 或 `bonsoir`）与网络状态插件（`connectivity_plus`），在 `mobile/android/app/src/main/AndroidManifest.xml` 与 `mobile/ios/Runner/Info.plist` 补齐组播及本地网络/Bonjour 权限；执行 `flutter pub get` 验证依赖拉取成功。
- [x] 2.2 实现 `mobile/lib/core/theme_controller.dart`（完整封装 Web 端 7 套多巴胺主题并基于 `SharedPreferences` 持久化），接入 `mobile/lib/main.dart` 驱动 `ShadApp` 与 `ShadToaster`；编写 Widget 测试验证切换主题后配色即时更新且持久化生效。
- [x] 2.3 实现 `mobile/lib/core/network_route_manager.dart`（维护内网/外网双地址、蜂窝网络 0ms 快轨、WiFi 1.2s 并发竞速与 `/api/health`->`/health` 兼容探测、Dio 请求超时容灾降级）与 `mobile/lib/core/lan_discovery_service.dart`（扫描 `_traceitem._tcp`）；编写单元测试验证选线与容灾逻辑通过。
- [x] 2.4 扩展 `mobile/lib/core/api_service.dart` 补齐 `getAuthConfig`、`register`、`updateMe`、`createHouse`、`updateHouse`、`deleteHouse`、`getItemDetail`、`resolveMediaUrl` 及物品 `category_id` 提交支持，并清理 `mobile/lib/widgets/item_card.dart` 与音视频播放器中的硬编码 `defaultBaseUrl`；执行 `flutter analyze` 验证无警告错误。

## 3. 纯净登录、受控注册与双路地址配置

- [x] 3.1 重构 `mobile/lib/screens/login_screen.dart`：移除快捷登录按钮与默认填充凭证，接入 `GET /api/auth/config` 动态展示「账号登录 / 注册新账号」Tab 与注册表单（`POST /api/auth/register`），对 `admin` 登录弹出 `ShadDialog` 友好拦截，并在底部实现双态服务线路引导/状态胶囊；编写 Widget 测试覆盖空初始表单、注册开关联动与 admin 拦截弹窗。
- [x] 3.2 升级 `mobile/lib/widgets/server_config_dialog.dart` 为内外网双地址配置弹窗（支持内网/外网地址录入、一键「自动发现内网服务」及双向连通耗时测试，统一使用 `ShadDialog` / `ShadToaster` 与 `>= 12px` 字号）；执行 `flutter analyze` 并验证交互逻辑。

## 4. 左侧抽屉导航壳层、自适应顶栏与首页重构

- [x] 4.1 新建 `mobile/lib/widgets/main_top_bar.dart`（一级页 `☰` 菜单与二级页 `←` 返回自适应切换，右侧动态渲染路由器/地球/断网图标并点击弹出 `ShadPopover` 展示线路详情与手动重连内网按钮）和 `mobile/lib/widgets/main_drawer_content.dart`（顶部名片 + 齿轮进设置，下方仅保留用户数据菜单且字号 `>= 12px`）；通过 Widget 测试验证抽屉导航与顶栏返回状态切换。
- [x] 4.2 新建 `mobile/lib/screens/main_shell_screen.dart` 统筹左侧 `Drawer`、一级目标页切换（`itemsHome`、`quickAdd`、`spaceManage`、`categoryManage`、`settings`）与系统返回键拦截；验证各一级页面间切换流畅且无底部 Tab。
- [x] 4.3 重构 `mobile/lib/screens/home_screen.dart`（控制在 `< 400` 行）并升级 `mobile/lib/widgets/space_anchor_bar.dart`，新增「全部空间 / 切换房屋」`ShadSheet` 选择器、物品品类筛选 `ShadSheet`、搜索与语音寻物及双列网格渲染；编写 Widget 测试验证房屋/房间/分类组合筛选正确更新列表。

## 5. 全屏物品详情、全模态编辑与空间/分类管理页

- [x] 5.1 新建全屏 `mobile/lib/screens/item_detail_screen.dart` 替代 `MediaPreviewDialog` 弹窗，支持多图切换与 `InteractiveViewer` 手势缩放、`DopamineVideoPlayer`、`DopamineAudioPlayer`、空间路径与标签展示，以及底部常驻「编辑」与「删除」（`ShadDialog` 危险确认）；编写 Widget 测试验证缩放与删除确认弹窗。
- [x] 5.2 升级 `mobile/lib/screens/item_edit_screen.dart` 并拆分 `mobile/lib/widgets/item_edit_media_section.dart` 与 `mobile/lib/widgets/tag_autocomplete_field.dart`（确保单文件 `< 500` 行），补齐启用分类选择、多图增删、15 秒短视频采集/选取、60 秒语音录制、`/items/tags/suggest` 标签联想及 `ShadToaster` 校验提示；执行 `flutter analyze` 并验证新增/编辑保存闭环。
- [x] 5.3 新建 `mobile/lib/screens/space_manage_screen.dart` 与 `mobile/lib/widgets/house_room_form_sheet.dart`（`ShadSheet`），实现房屋与房间完整 CRUD（严格分离 10 款房屋建筑 Emoji 与房间功能 Emoji）、`ShadDialog` 级联删除警告，以及点击房屋/房间直达首页对应筛选视图；编写 Widget 测试验证空间 CRUD 与危险确认流程。
- [x] 5.4 将分类管理重构为独立一级页面 `mobile/lib/screens/category_manage_screen.dart`，支持 Emoji 选择新建、行内/抽屉编辑、排序调整、启停切换及 `ShadDialog` 安全解绑删除确认；执行 `flutter analyze` 并验证分类生命周期交互。

## 6. 纯软件设置二级页栈与全局规范验收

- [x] 6.1 构建 `mobile/lib/screens/settings/settings_screen.dart` 及子页面栈（`user_profile_screen.dart`、`change_password_screen.dart`、`server_config_screen.dart`、`theme_settings_screen.dart`），确保仅承载软件与账号设置（`PUT /api/auth/me`、内外网地址与 mDNS 发现、7 套多巴胺主题网格、缓存清理与 `ShadDialog` 退出确认）；验证所有页面字号 `>= 12px` 且完整响应主题切换。
- [x] 6.2 执行全面验收检查：统计所有新增与修改的 `.dart`/`.py` 文件行数确保严格 `< 500` 行，检索确认无原生 `alert`/`confirm`/`SnackBar` 残留，运行 `flutter analyze`、`flutter test`、后端 `pytest` 及 `openspec validate mobile-drawer-redesign --strict` 全部通过。
