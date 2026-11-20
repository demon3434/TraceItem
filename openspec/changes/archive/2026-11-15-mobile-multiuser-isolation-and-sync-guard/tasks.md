# Tasks

## 1. 服务端乐观锁与媒体鉴权加固

- [x] 1.1 在 `server/app/models/item.py` 与 `server/app/db/init_db.py` 为 `Item` 新增 `version` 字段（默认 `1`），并为存量 SQLite 数据库补充幂等 `ALTER TABLE items ADD COLUMN version` 平滑迁移逻辑
- [x] 1.2 更新 `server/app/schemas/item.py`（`ItemOut.version`、`ItemUpdate.expected_version`）与 `server/app/services/item_service.py`，在 `update_user_item` 中校验版本一致性（不匹配返回 HTTP `409 Conflict`）并在成功更新时递增 `version`
- [x] 1.3 在 `server/app/api/media.py` 为 `GET /api/media/file/{file_path:path}` 增加 JWT 鉴权校验（支持 `Authorization: Bearer` 与 `?token=` 查询参数），未认证请求返回 HTTP `401`
- [x] 1.4 编写并运行服务端单元测试，验证乐观锁 `409` 拦截（不误删附件）与媒体接口 `401` 鉴权拦截全部通过

## 2. 移动端安全存储与多用户隔离

- [x] 2.1 在 `mobile/pubspec.yaml` 引入 `flutter_secure_storage`，更新 `ApiService`（`initFromStorage`、`login`、`logout`）实现 `auth_token` 安全存储与旧版明文 Key 自动迁移清理，确保单文件严格 `<500` 行
- [x] 2.2 改造 `mobile/lib/core/media_cache_manager.dart` 支持按 `user_id` 分桶目录（`u_{userId}/`）与独立索引键，保持设备级总配额与跨分桶全局 LRU 淘汰，并在初始化时清理历史扁平缓存残余
- [x] 2.3 改造 `mobile/lib/core/theme_controller.dart` 支持按 `user_id` 隔离主题配色（`traceitem_theme_u_{userId}`），登出时恢复默认主题且保留设备级服务器地址配置
- [x] 2.4 更新 `mobile/lib/screens/settings/media_storage_screen.dart`，展示「当前账号缓存 / 本机总缓存与设备上限」，并确保「立即清空缓存」经危险态 `ShadDialog` 确认后仅清除当前用户缓存目录与内存 `imageCache`

## 3. 移动端 401 被动登出、媒体鉴权与跨期同步保护

- [x] 3.1 在 `ApiService` 注册全局 `onUnauthorized` 回调与 Dio `401` 拦截器（排除登录/注册端点），触发时自动清理会话、内存图片缓存与 `AppLogger` 日志，跳转至 `LoginScreen` 并通过 `CustomDialogs.showToast` 提示
- [x] 3.2 更新移动端图片与音视频加载组件（`MobileItemCard`、`ItemDetailImageGrid`、`ItemDetailGallery`、`DopamineAudioPlayer`、`DopamineVideoPlayer`、`MediaCacheManager`），统一在媒体请求中携带有效鉴权凭据
- [x] 3.3 更新 `mobile/lib/models/models.dart` 与 `mobile/lib/screens/item_edit_screen.dart`，在 `Item` 模型解析 `version` 并在保存时透传 `expected_version`，收到 `409` 时弹出 `ShadDialog` 引导刷新最新物品数据
- [x] 3.4 在 `mobile/lib/screens/main_shell_screen.dart` 监听 `AppLifecycleState.resumed`，后台挂起超过 5 分钟切回前台时自动触发路由重探与 `HomeScreen` 元数据/物品静默刷新

## 4. Web 端兼容性适配与全端验证发布

- [x] 4.1 更新 Web 端物品类型与编辑提交流程，在 `PUT /api/items/{id}` 透传 `expected_version` 并对 `409 Conflict` 使用 `shadcn-vue` Dialog/Sonner 给出冲突刷新提示（严禁原生 `alert`/`confirm`）
- [x] 4.2 运行 `flutter analyze` 与 `flutter test` 验证移动端静态检查与测试通过，检查所有新建/修改文件行数严格 `<500` 行
- [x] 4.3 部署最新后端与 Web 服务至 `186` 服务器并验证接口健康检查，随后执行 `flutter build apk --release --target-platform android-arm64` 生成 ARMv8 Release APK

## 5. 服务端离线幂等支持

- [x] 5.1 在 `server/app/models/item.py` 与 `server/app/db/init_db.py` 为 `Item` 新增 `client_uuid` 字段及 `(user_id, client_uuid)` 唯一索引（含存量 SQLite 平滑迁移）
- [x] 5.2 更新 `server/app/schemas/item.py` 与 `server/app/services/item_service.py`，在 `create_user_item` 中支持基于 `client_uuid` 的幂等创建并补充服务端 pytest 幂等性测试

## 6. 移动端离线录入、草稿隔离与 Outbox 同步

- [x] 6.1 在 `mobile/pubspec.yaml` 显式声明 `sqflite` 依赖，新增 `offline_db.dart`、`offline_draft_storage.dart`（独立 `offline_drafts/u_{userId}/`）与 `meta_snapshot_store.dart`（房屋/房间/分类/标签本地快照）
- [x] 6.2 改造 `mobile/lib/widgets/item_edit_media_section.dart` 及缩略图预览组件支持延迟上传与本地文件预览（`Image.file` / 本地播放器），保持单文件严格 `<500` 行
- [x] 6.3 新增 `offline_sync_service.dart` 实现基于 `connectivity_plus` 与前台唤醒的 Outbox 自动按序同步（先传媒体再幂等提交 `createItem`，成功后转存 `MediaCacheManager` 并清理草稿）
- [x] 6.4 改造 `mobile/lib/screens/item_edit_screen.dart` 与 `mobile/lib/screens/home_screen.dart`，支持离线保存入队及顶部「待同步草稿」状态胶囊（支持查看原因、手动重试与放弃草稿），确保所有文件 `<500` 行

## 7. 离线录入联调验证、186 重部署与新版 APK 打包

- [x] 7.1 编写并运行移动端离线入队/多用户隔离/幂等同步单元测试，确认 `flutter analyze` 零问题
- [x] 7.2 重新部署后端至 `186` 服务器并构建新版 ARMv8 (`arm64-v8a`) Release APK

## 8. 存量物品离线编辑/删除与字段级冲突合并

- [x] 8.1 在 `server/app/models/item.py`、`server/app/db/init_db.py` 与 `server/app/schemas/item.py` 新增 `field_versions_json` 字段级版本追踪列与 `ItemPatchUpdate` / `client_op_uuid` 幂等支持（含存量 SQLite 平滑迁移）
- [x] 8.2 更新 `server/app/services/item_service.py` 与 `server/app/api/items.py`，实现 `PUT` 字段级三向自动合并、同字段冲突返回 `409`（附 `conflict_fields` 与最新物品快照）及 `DELETE` `expected_version` 校验，并补充 pytest 测试
- [x] 8.3 扩展 `mobile/lib/core/offline_db.dart` 与 `mobile/lib/screens/home_screen.dart` / `item_edit_screen.dart`，新增按 `user_id` 隔离的 `cached_items` 本地缓存、离线编辑增量 `changed_fields` 采集、离线删除标记与 Outbox 操作折叠
- [x] 8.4 更新 `mobile/lib/core/offline_sync_service.dart` 与 `mobile/lib/widgets/offline_outbox_banner.dart`，支持 `update`/`delete` 增量同步及 `conflict` 状态的 `ShadSheet` 对比仲裁界面（覆盖本机 / 放弃冲突修改）
- [x] 8.5 补充移动端增量合并与折叠单元测试，确认 `flutter analyze` 与单文件 `<500` 行全部通过，重部署 `186` 并构建新版 ARMv8 Release APK

## 9. Web 端右上角统一「设置」菜单与改密/改昵称闭环

- [x] 9.1 封装 Web 端右上角「设置 (`Settings`)」一级按钮与下拉菜单组件（整合切换主题、修改密码、修改昵称、退出登录），替换 `web/src/components/space/SpaceAnchorBar.vue` 原有并排主题与退出按钮，确保单文件 `<300` 行
- [x] 9.2 实现修改昵称与修改密码 `shadcn-vue` Dialog（严禁原生 `alert`/`confirm`/`prompt`，调用 `PUT /api/auth/me`），改密成功后自动清理本地会话跳转登录页
- [x] 9.3 执行 `web npm run build` 校验构建通过，并重部署至 `186` 服务器验证页面生效
