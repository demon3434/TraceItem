# mobile-sync-and-concurrency-guard Specification

## Purpose

定义跨设备或跨期编辑物品时的乐观锁并发冲突防护、移动端后台唤醒自动同步以及全局会话失效自动登出机制，确保多手机交替使用时不发生数据静默覆盖或旧态卡死。

## Requirements

### Requirement: 物品乐观锁并发冲突检测与防护
服务端与移动端 SHALL 为物品实体维护单调递增的版本号 `version`，在更新物品时校验 `expected_version`，防止旧设备或挂起页面覆盖其他设备的最新修改与附件。

#### Scenario: 乐观锁版本匹配时正常更新并递增版本号
- **WHEN** 客户端提交 `PUT /api/items/{id}` 并携带与服务端当前一致的 `expected_version`（或兼容旧客户端未传 `expected_version`）
- **THEN** 服务端 SHALL 执行更新、将 `item.version` 递增 `1` 并返回更新后的完整物品数据

#### Scenario: 版本不一致时拒绝覆盖并返回 409 冲突
- **WHEN** 设备 A 基于旧版本 `version = 1` 提交 `PUT /api/items/{id}`，而服务端已因设备 B 更新升级至 `version = 2`
- **THEN** 服务端 SHALL 拒绝本次修改、保留现有数据与物理附件不被删除，并返回 HTTP `409 Conflict`
- **THEN** 移动端 `ItemEditScreen` SHALL 弹出 `ShadDialog` 提示「该物品已在其他设备被更新」，引导用户刷新最新内容后再编辑

### Requirement: 全局 401 会话失效自动登出
移动端网络层 SHALL 统一拦截业务请求返回的 HTTP `401 Unauthorized` 响应，自动清理失效会话并引导用户重新登录。

#### Scenario: 旧设备 Token 过期或在其他端改密后触发 401
- **WHEN** 已登录状态下任意非登录/注册业务请求返回 HTTP `401`
- **THEN** `ApiService` SHALL 自动执行本地会话清理（移除安全存储中的凭据与内存状态），触发全局登出导航回调跳转至 `LoginScreen`，并通过 `CustomDialogs.showToast` 提示登录已过期

### Requirement: 前台唤醒静默刷新元数据与线路重探
移动端主壳层 SHALL 监听应用前后台生命周期，在长时间挂起后切回前台时自动刷新空间、分类与物品状态。

#### Scenario: 后台挂起超过 5 分钟后切回前台
- **WHEN** App 从后台状态恢复为 `AppLifecycleState.resumed` 且距离上次活跃同步超过 5 分钟
- **THEN** 系统 SHALL 静默触发内网/外网路由重探并刷新当前用户的房屋、房间、分类及物品列表，避免使用已停用或已删除的旧空间引用

### Requirement: 移动端离线新建录入与延迟媒体暂存
移动端 SHALL 支持已登录用户在无网或弱网环境下使用最近一次在线同步的空间与分类快照创建新物品，并将端侧压缩后的多模态附件暂存至独立于缓存池的本地草稿目录。

#### Scenario: 断网状态下拍摄附件并保存物品至 Outbox
- **WHEN** 已登录用户在无网环境打开 `ItemEditScreen` 新增物品，拍摄/录制图片、音频或短视频并点击保存
- **THEN** 客户端 SHALL 使用本地快照提供房屋、房间与分类选择，将压缩后的媒体落盘至 `offline_drafts/u_{userId}/` 并本地预览，生成唯一 `client_uuid` 后将任务写入当前用户的本地 SQLite `offline_outbox` 队列，并通过 `CustomDialogs.showToast` 提示已进入待同步队列

#### Scenario: 离线草稿与媒体缓存物理隔离
- **WHEN** 用户在设置页执行「清空当前账号媒体缓存」或触发设备级 LRU 自动淘汰
- **THEN** `offline_drafts/u_{userId}/` 与 `offline_outbox` 中的待同步媒体与记录 SHALL 保持完好不被清除

### Requirement: Outbox 自动同步与服务端 client_uuid 幂等入库
移动端 SHALL 在网络恢复或回到前台时自动按序上传当前登录用户的待同步草稿，服务端 SHALL 基于 `client_uuid` 保证新建物品的幂等性。

#### Scenario: 网络恢复后自动按序同步并转存缓存
- **WHEN** 设备恢复网络连接或用户手动点击 `HomeScreen` 顶部「待同步草稿」重试
- **THEN** 同步器 SHALL 仅处理当前登录 `user_id` 的 `pending`/`failed` 任务，依次上传未上传的本地媒体换取服务端路径，再携带 `client_uuid` 调用 `POST /api/items` 入库，成功后将媒体转存至 `MediaCacheManager`、清理对应草稿并刷新物品列表

#### Scenario: 弱网重试时服务端基于 client_uuid 幂等防重
- **WHEN** 客户端因弱网超时重复提交携带相同 `(user_id, client_uuid)` 的 `POST /api/items` 请求
- **THEN** 服务端 SHALL 返回既有物品记录而不重复创建第二条物品

#### Scenario: 同步遇空间失效等业务错误时保留草稿并提示
- **WHEN** Outbox 同步因目标房间已停用或删除返回 HTTP `400` 等业务错误
- **THEN** 同步器 SHALL 将该记录标记为 `failed` 并记录错误原因，在 `HomeScreen` 待同步队列卡片中提示用户，支持打开编辑或放弃该草稿

### Requirement: 存量物品本地缓存与离线编辑增量入队
移动端 SHALL 缓存当前用户的存量物品快照，并在离线编辑或删除时生成增量变更集写入 Outbox，支持本地操作折叠。

#### Scenario: 离线编辑存量物品生成增量 Patch 与附件差集
- **WHEN** 已登录用户在无网环境下打开本地缓存的存量物品进行编辑并保存
- **THEN** 客户端 SHALL 仅计算相对基线快照的 `changed_fields` 与附件增删差集（`added_attachments` / `removed_attachment_paths`），连同 `base_version` 与 `client_op_uuid` 写入 `offline_outbox` 并同步更新本地 `cached_items` 展示

#### Scenario: 同一物品多次离线操作本地折叠
- **WHEN** 用户在断网期间对同一离线新建草稿再次编辑或直接删除，或对同一存量物品连续编辑多次
- **THEN** 客户端 SHALL 在本地 Outbox 原地折叠合并（`create + delete` 直接本地销毁；多次 `update` 合并 `changed_fields` 并集且保留初始 `base_version`）

### Requirement: 服务端字段级三向自动合并与真冲突仲裁
服务端 SHALL 追踪物品各字段的最近修改版本号，在并发离线更新时自动合并无交集字段，仅在同字段碰撞时返回 `409` 引导用户仲裁。

#### Scenario: 并发修改不同字段时服务端自动三向合并
- **WHEN** 设备 A 离线仅修改 `quantity`（携带 `base_version = 3`），而设备 B 已在线修改 `room_id` 使 `server.version` 升至 `4`
- **THEN** 服务端 SHALL 校验 `quantity` 的字段版本号 `<= 3`，自动合并更新 `quantity` 并递增 `version` 至 `5` 返回成功

#### Scenario: 并发修改同一字段时拦截并返回 409 与冲突对比详情
- **WHEN** 设备 A 离线修改 `location_detail` 且服务端 `field_versions_json["location_detail"] > base_version`
- **THEN** 服务端 SHALL 拒绝覆盖并返回 HTTP `409 Conflict`（含 `conflict_fields` 与最新 `Item` 数据），移动端将该草稿标为 `conflict` 并在首页引导用户通过 `ShadSheet` 选择「保留本机覆盖」或「放弃本机冲突修改」

### Requirement: 离线删除安全边界与幂等处理
服务端与移动端 SHALL 在离线删除同步时校验物品版本，防止误删他人离线期间更新过的物品，同时保证重复删除幂等。

#### Scenario: 离线删除期间他人已更新物品则拦截
- **WHEN** 离线删除请求携带的 `base_version` 小于服务端当前 `version`
- **THEN** 服务端 SHALL 返回 HTTP `409 Conflict` 阻止删除，移动端将该任务标为 `conflict` 交由用户确认是否仍要强制删除或恢复显示

#### Scenario: 目标物品已被删除时离线删除视为幂等成功
- **WHEN** 离线删除同步时服务端返回 HTTP `404`
- **THEN** 移动端 SHALL 视为幂等成功并清理本地 `cached_items` 与对应 Outbox 记录

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

### Requirement: Empty Remote Item Response Cache Invalidation
当移动端物品寻宝首页拉取远端物品列表返回为空（且当前为第 1 页、无搜索关键字过滤）时，移动端 SHALL 显式清理本地 SQLite 离线数据库（`cached_items`）中对应筛选维度的缓存记录，严禁保留已被清空或不存在的残留脏数据。

#### Scenario: 云端空间为空时自动清理本地残留缓存
- **WHEN** 移动端拉取当前房屋或默认空间的第 1 页物品，服务端明确返回空列表（total 为 0）
- **THEN** 移动端清除本地数据库中当前用户对应房屋/范围的 `cached_items` 记录，界面展示空状态而非历史残留物品
