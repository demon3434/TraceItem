# Design

## Context

参见 `proposal.md`。现有部署脚本将本地开发库与多媒体目录全量打包，导致测试数据泄露至部署机；同时移动端离线数据缓存（`cached_items`）缺少服务端实例世代感知能力，在切换 IP 或重置数据库时容易发生跨实例脏数据复用。

## Goals / Non-Goals

**Goals:**
- **新部署绝对纯净**：构建工件与自动化部署包剔除一切开发机本地数据库文件与测试媒体附件，首次建库仅生成 Admin 账号与通用分类模板，用户与物品数据保持 0 状态。
- **服务实例世代感知（Fingerprint Handshake）**：服务端提供持久化实例指纹 `server_instance_id`，客户端据此精确区分“同一服务换局域网 IP”与“连接到不同/全新服务实例”。
- **客户端全自动无感自愈**：指纹匹配时平滑更新路由；指纹不匹配时代码自动清除旧会话、清空本地离线数据库与快照，安全退回登录页，彻底摆脱用户手动清缓存。
- **全流程自动化部署与镜像归档**：更新打包部署流水线（`scripts/deploy_to_186.py` 及阿里云镜像推送脚本），支持清空远端历史旧持久化脏数据并自动清理服务器悬空过时镜像。

**Non-Goals:**
- 不引入外部分布式服务注册中心（Consul/Etcd 等），依赖轻量 HTTP 握手与响应头/体字段。
- 不修改既有的 SQLite WAL 模式、FTS5 全文索引或单文件 <500 行核心规范。

## Decisions

### 1. 服务端实例指纹持久化机制
- **方案决策**：在 SQLite 数据库首建时生成 UUID4 作为 `server_instance_id`，持久化至系统配置表；并在 `init_db()` 时保证只要 `items.db` 文件存在，该 UUID 不变。
- **接口透出**：通过 `GET /health`、`GET /api/health` 与 `GET /api/auth/config` 的 `data.server_instance_id` 输出。
- **备选考量**：曾考虑每次服务进程重启随机生成实例 ID，但该方式会导致服务器正常重启时引起所有手机强制登出与离线草稿丢失，故必须与物理数据库生命周期严格绑定。

### 2. 部署打包黑白名单隔离
- **方案决策**：
  - 修改 `deploy_to_186.py` 打包逻辑，对 `server/data/` 目录执行严格过滤：仅允许包含离线语音识别模型目录 `server/data/models/`，绝对排除 `*.db*`、`media/` 及临时文件。
  - 远端部署时提供一键重置标志或参数，彻底清理远端挂载目录的旧持久化数据。
- **备选考量**：曾考虑完全不挂载 `./data`，但离线语音模型体积较大，保留目录挂载但剔除动态业务数据是平衡部署速度与纯净度的最佳选择。

### 3. 移动端实例自愈策略
- **方案决策**：
  - `NetworkRouteManager` 与 `ApiService` 本地持久化保存 `last_server_instance_id`。
  - 在探测网络（`detectAndSwitchBestRoute`）和请求健康检查时比对实例指纹：
    - 若 `server_instance_id` 一致：仅更新 `intranet_url`/`extranet_url`，保持会话与离线缓存。
    - 若 `server_instance_id` 发生改变（或从无指纹切换到有指纹）：调用 `OfflineDb.instance.clearAllCache()`、`MetaSnapshotStore.clearAllSnapshots()`、`MediaCacheManager.instance.clearAllCache()` 及 `ApiService.logout()`，并弹出轻提示：“检测到连接至新的家庭账本服务，已重置本地工作区”。
  - 首页在拉取远端物品返回 0 件且为第 1 页时，主动调用 `OfflineDb.clearScopeCache()` 抹除脏缓存。

### 4. 阿里云镜像推送与远端镜像垃圾清理 (Prune)
- **方案决策**：
  - 规范化镜像标签：构建本地镜像 `traceitem-app:latest`，推送到阿里云镜像仓库（如 `crpi-*.cn-shanghai.personal.cr.aliyuncs.com/zixidaxian/traceitem:latest`）。
  - 在远端玩客云执行重新拉取/构建部署后，自动执行 `docker image prune -f`，清理构建缓存与 `<none>` 悬空过时镜像，防止玩客云内置磁盘膨胀。

## Risks / Trade-offs

- **[风险] 换服自动注销可能导致未提交草稿丢失**  
  → *缓解措施*：在清空离线缓存前，检查 `OfflineSyncService.drafts`；若存在未同步草稿，将其备份或标记转移，避免静默丢失；若用户主动连接不同服务器，在切换时明确提醒。
- **[风险] 弱网超时导致实例指纹暂时读取失败**  
  → *缓解措施*：仅在握手明确获取到与本地不同的 `server_instance_id` 时触发重置序列，网络连接失败时不触发误重置。

