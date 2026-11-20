# Design

## Context

详见 `proposal.md - Why`。当前移动端为纯在线瘦客户端（无本地业务数据库），后端基于 FastAPI + SQLite 3 (WAL + FTS5)。需要遵守单文件 `<500` 行、`ShadDialog` / `CustomDialogs` 统一弹出层、以及 ARMv8 (`arm64-v8a`) Release 打包等全局约束。

## Goals / Non-Goals

**Goals:**
- 实现基于 `user_id` 的本地磁盘媒体缓存分桶与主题偏好隔离，同时保持设备级共享磁盘配额与服务器配置。
- 将敏感凭据迁入系统安全存储，补齐全局 `401` 自动登出与静态媒体接口鉴权。
- 引入后端 `Item.version` 乐观锁、`field_versions_json` 字段级版本追踪与移动端后台唤醒静默同步，支持离线新建、存量物品离线编辑/删除与三向自动合并。

**Non-Goals:**
- 暂不支持离线新建或修改房屋/房间/分类（空间与分类结构仍需在线维护并同步至本地快照）。
- 不修改现有空间层级（House -> Room）或 Web 端管理台既有业务流程（Web 端仅兼容透传 `version` / `expected_version`）。

## Decisions

### Decision 1: 多用户本地缓存分桶 + 设备级共享配额
- **方案**：`MediaCacheManager` 在 `getApplicationSupportDirectory()/traceitem_media_cache/` 下按 `u_{userId}/` 建子目录，索引存于 `SharedPreferences` 的 `traceitem_media_cache_index_u_{userId}`；设备总配额 `traceitem_media_cache_quota_mb` 保持全局共享。触发 LRU 淘汰时扫描全部分桶索引并按 `lastAccessed` 淘汰至 80% 水位；设置页「立即清空缓存」仅清空当前登录用户分桶。
- **备选方案**：退出登录时直接全删本地磁盘缓存。
- **理由**：家庭共享设备切换账号频繁，且未来需要支持离线录入草稿箱；按 `user_id` 分桶既杜绝串号与隐私泄露，又避免反复拉取媒体流量，同时保护设备总存储不超限。

### Decision 2: `flutter_secure_storage` 存储 Token 与平滑迁移
- **方案**：引入 `flutter_secure_storage` 存储 `auth_token`；`ApiService.initFromStorage()` 启动时优先读取安全存储，若为空则检查旧版 `SharedPreferences('auth_token')`，存在即迁移写入安全存储并删除旧明文键。
- **备选方案**：继续使用 `SharedPreferences` 或自研 AES 加密。
- **理由**：`flutter_secure_storage` 原生调用 Android Keystore / iOS Keychain，符合业界安全规范且零破坏升级。

### Decision 3: `Item` 整数版本号乐观锁（`version` + `expected_version`）
- **方案**：在 `items` 表新增 `version INTEGER NOT NULL DEFAULT 1`。`ItemUpdate` 增加 `expected_version: Optional[int] = None`；若请求携带该字段且与数据库当前 `item.version` 不等，直接抛出 HTTP `409 Conflict`；更新成功时 `item.version += 1`。
- **备选方案**：使用 `updated_at` 时间戳比对。
- **理由**：SQLite 与 JSON 序列化存在毫秒精度与时区格式差异，整数 `version` 严格单调递增、零歧义且兼容旧客户端（未传 `expected_version` 时暂不拦截）。

### Decision 4: 媒体接口鉴权兼容原生播放器与 `Image.network`
- **方案**：`GET /api/media/file/{file_path:path}` 校验 `Authorization: Bearer <token>` Header 或查询参数 `?token=<jwt>`（通过 `decode_access_token` 验证有效用户）。移动端 `Image.network`、`Dio` 下载以及 `VideoPlayerController.networkUrl(..., httpHeaders: ...)` 统一附带 `Authorization` Header（若播放器底层不支持自定义 Header 时回退使用当前会话 Token）。
- **备选方案**：签发独立短时效 Media Signed URL。
- **理由**：TraceItem 为局域网/私有云自部署架构，直接复用现有 JWT + Header/Query 校验改动最小、与 `ApiService.resolveMediaUrl` 兼容最好，且能立即阻断未认证直连。

### Decision 5: `AppLifecycleState.resumed` 节流静默刷新与全局 `401` 回调
- **方案**：在 `ApiService` 注册 `onUnauthorized` 全局回调，Dio `onError` 收到非 `/auth/login`、`/auth/register` 的 `401` 时防抖触发 `logout()` 并导航至 `LoginScreen`。`MainShellScreen` 混入 `WidgetsBindingObserver`，记录上次活跃时间戳，后台切回前台超过 5 分钟时触发路由重探及 `HomeScreen` 静默刷新。

### Decision 6: 离线录入 Outbox 发件箱与独立草稿目录
- **方案**：引入 `sqflite` 建立 `offline_outbox` 表，每条任务绑定 `user_id`、`client_uuid`、`payload_json`、`media_tasks_json` 与状态（`pending` / `uploading` / `failed` / `conflict`）。所有未上传的端侧压缩媒体存放于 `getApplicationSupportDirectory()/offline_drafts/u_{userId}/`，与 `traceitem_media_cache/` 完全隔离。

### Decision 7: 存量物品本地缓存、增量变更集与字段级三向合并
- **方案**：
  - **本地只读缓存（`cached_items`）**：在 `traceitem_offline.db` 新增按 `user_id` 隔离的 `cached_items` 表，在线拉取物品列表/详情时写入快照，断网时支持打开存量物品详情与编辑页，离线删除时先在本地标记 `pending_delete` 隐藏。
  - **增量变更集（Delta Patch）+ Outbox 折叠**：离线编辑存量物品时不提交全量表单，而是对比基线快照只记录 `op_type`（`update` / `delete`）、`base_version`、`client_op_uuid`、`changed_fields` 及附件增量（`added_attachments` / `removed_attachment_paths`）。同一离线草稿的多次编辑原地折叠，离线新建后直接删除则在本地抵消销毁。
  - **服务端字段级三向判定**：`items` 表新增 `field_versions_json` 记录各字段最新修改版本号；`PUT` 请求携带 `base_version` 与 `changed_fields` 时，若 `server.version == base_version` 直接更新；若 `server.version > base_version` 且 `changed_fields` 中所有字段在 `field_versions_json` 的版本号均 `<= base_version`，则**服务端自动无感合并**；若存在同字段碰撞（`field_version > base_version`），返回 `409 Conflict` 及 `conflict_fields` + 服务端最新快照，由客户端弹出 `ShadSheet` 对比仲裁（覆盖本机 / 放弃冲突字段）。
  - **离线删除边界**：服务端收到 `DELETE` 附带 `expected_version` 时，若目标已不存在（`404`）按幂等成功处理；若 `server.version > base_version` 则拦截返回 `409`，防止误删他人离线期间刚更新过的物品。

### Decision 8: Web 端右上角统一「设置」一级菜单与账号安全闭环
- **方案**：将 `SpaceAnchorBar.vue` 右上角原本并排的「主题切换」与「退出登录」（及管理员改密按钮）整合为单个 Lucide `Settings` 一级图标按钮。点击展开统一下拉面板，提供 **切换主题**（5 套多巴胺主题）、**修改密码**、**修改昵称**、**退出登录** 四项操作；其中「修改密码」与「修改昵称」通过 `shadcn-vue` Dialog 表单调用 `PUT /api/auth/me`，修改密码成功后因服务端 `token_version` 自增，前端提示并清理本地会话跳转登录页。

## Risks / Trade-offs

- **[Risk] 存量 SQLite 数据库缺少 `items.version` 列导致启动报错** → **Mitigation**: 在 `server/app/db/init_db.py` 初始化阶段检测 `PRAGMA table_info(items)`，若缺失 `version` 列则自动执行 `ALTER TABLE items ADD COLUMN version INTEGER NOT NULL DEFAULT 1;` 实现零停机迁移。
- **[Risk] `Android` 部分机型 `VideoPlayer` 或 `AudioPlayer` 流式请求不透传自定义 `httpHeaders`** → **Mitigation**: 服务端 `serve_media_file` 同时支持 `Authorization` Header 与 `?token=` Query 参数，且移动端优先走 `MediaCacheManager`（Dio 带 Header 下载后播本地文件），双重保障不翻车。
- **[Risk] 升级后旧版扁平缓存目录 `traceitem_media_cache/` 遗留孤儿文件** → **Mitigation**: `MediaCacheManager.init()` 首次按新分桶初始化时，清理旧版 `traceitem_media_cache_index` 键及根目录下的历史非 `u_*` 散落缓存文件。

