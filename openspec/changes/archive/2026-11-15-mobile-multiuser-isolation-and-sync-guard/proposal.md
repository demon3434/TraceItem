# Proposal

## Why

当前移动端以纯在线瘦客户端模式运行，虽然不存在本地业务数据库损坏问题，但在多用户同机切换登录与多设备跨期使用场景下存在三类工程隐患：
1. **本地用户态隔离不彻底**：多媒体磁盘缓存池（`MediaCacheManager`）、内存图片缓存、主题偏好及诊断日志均未按 `user_id` 分桶且在退出登录时不清理，导致前任用户数据残留或挤占公共缓存配额；同时认证凭据使用明文 `SharedPreferences` 存储，服务端静态媒体端点缺乏登录鉴权。
2. **认证失效缺乏全局被动登出**：`ApiService` 拦截器未处理 HTTP `401`，当旧设备 Token 过期或在其他设备改密后，界面停留在工作区且操作反复报错。
3. **跨设备跨期编辑缺乏并发保护**：`Item` 更新接口无乐观锁版本号校验，旧设备挂起恢复后保存会直接覆盖新设备修改甚至物理删除新上传的附件；且 App 从后台长时间切回前台时未自动刷新空间与物品元数据。

## What Changes

- **移动端多用户隔离与安全存储加固**：
  - 将认证凭据（`auth_token`）迁移至系统安全存储（`flutter_secure_storage`），退出登录时彻底清除内存态与当前用户图片内存缓存/诊断日志。
  - `MediaCacheManager` 改造为按 `user_id` 分桶目录（`traceitem_media_cache/u_{userId}/`）与独立索引存储；缓存配额上限（`quotaMb`）保持设备级共享预算并执行全局 LRU 淘汰，而设置页「立即清空缓存」默认仅清理当前登录账户目录并同时展示当前账户与本机总缓存体积。
  - `ThemeController` 支持按 `user_id` 隔离个人主题偏好（未登录时回退默认主题）。
- **全局 `401` 失效自动登出拦截**：
  - `ApiService` Dio 拦截器捕获非登录接口的 HTTP `401` 响应后，自动清理会话并触发全局导航回调跳转至 `LoginScreen`，并通过 `CustomDialogs.showToast` 给出温润提示。
- **跨端并发与跨期编辑保护**：
  - 后端 `Item` 模型新增 `version` 乐观锁字段（每次更新自增 `1`），`ItemUpdate` 支持 `expected_version` 校验；版本不一致时拒绝覆盖并返回 HTTP `409 Conflict`。
  - 移动端 `ItemEditScreen` 提交保存时携带 `expected_version`，遇 `409` 时弹出 `ShadDialog` 提示冲突并引导用户刷新最新物品详情，绝不误删其他设备新增的附件。
  - `MainShellScreen` 监听 `AppLifecycleState.resumed`，从后台长时间（>5 分钟）切回前台时自动静默重探最优线路并刷新房屋/房间/分类及物品列表。
- **服务端媒体访问鉴权**：
  - 为 `GET /api/media/file/{file_path:path}` 增加用户登录态校验（支持 `Authorization: Bearer <token>` 请求头或鉴权查询参数），移动端图片/音视频加载统一携带鉴权凭据。
- **移动端离线录入与 Outbox 自动同步（二阶段扩展：含存量编辑与删除合并）**：
  - 后端 `Item` 增加 `client_uuid` 幂等键（联合唯一约束 `(user_id, client_uuid)`）与 `field_versions_json` 字段级版本追踪、`client_op_uuid` 变更幂等记录，支持弱网防重与字段级三向自动合并。
  - 移动端引入本地 `sqflite` Outbox 发件箱、`cached_items` 存量物品本地缓存、独立 `offline_drafts/u_{userId}/` 草稿目录及空间/分类元数据快照（`meta_snapshot_u_{userId}`），支持无网环境下新建与存量编辑（增量 `changed_fields` + 附件增删差集）/删除入队；联网或切回前台时自动同步，不重叠修改自动合并，同字段碰撞在首页「待同步草稿」胶囊提示并通过 `ShadSheet` 对比仲裁。

## Capabilities

### New Capabilities
- `mobile-sync-and-concurrency-guard`: 定义跨设备/跨期编辑的乐观锁并发冲突防护（`version` / `409 Conflict`）、App 前后台切换静默刷新、全局 `401` 会话失效自动登出机制，以及离线录入草稿暂存、幂等入库与 Outbox 自动同步能力。

### Modified Capabilities
- `mobile-auth-and-lan-discovery`: 补充认证凭据安全存储（`flutter_secure_storage`）、多用户本地缓存与主题按 `user_id` 隔离、登出内存清理以及媒体文件访问鉴权要求。
- `mobile-media-and-performance`: 补充 `MediaCacheManager` 按 `user_id` 分桶存储、设备级配额共享与设置页「清空缓存」仅作用于当前账户的行为规范。

## Impact

- **后端 (`server/`)**：
  - `app/models/item.py`、`app/db/init_db.py`（兼容存量 SQLite 数据库的 `items.version` 平滑迁移）、`app/schemas/item.py`、`app/services/item_service.py`、`app/api/media.py`。
- **移动端 (`mobile/`)**：
  - `pubspec.yaml`（新增 `flutter_secure_storage`、`sqflite` 依赖）、`lib/models/models.dart`、`lib/core/api_service.dart`、`lib/core/media_cache_manager.dart`、`lib/core/theme_controller.dart`、以及新增离线库与同步模块（`offline_db.dart`、`offline_draft_storage.dart`、`meta_snapshot_store.dart`、`offline_sync_service.dart`）。
  - `lib/screens/main_shell_screen.dart`、`lib/screens/home_screen.dart`、`lib/screens/item_edit_screen.dart`、`lib/widgets/item_edit_media_section.dart`、`lib/screens/settings/media_storage_screen.dart`、`lib/widgets/item_card.dart`、`lib/widgets/dopamine_audio_player.dart`、`lib/widgets/dopamine_video_player.dart` 等媒体加载与编辑组件。
- **Web 端 (`web/`)**：
  - 兼容后端 `ItemOut.version` 新增字段，编辑提交时同步透传 `expected_version` 并在 `409` 时给出统一弹出层提示。
  - 将 `SpaceAnchorBar.vue` 右上角分散的「主题切换」与「退出登录」（及管理员改密快捷）按钮收拢为统一的「设置 (`Settings`)」一级功能按钮，下拉菜单集成「切换主题」「修改密码」「修改昵称」「退出登录」，并接入 `PUT /api/auth/me`（改密后触发重新登录）。

