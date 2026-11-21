# Proposal

## Why

在现有部署与多环境使用中存在两类突出的数据纯净度与客户端状态串扰问题：
1. **新部署存在测试数据污染**：部署脚本（如 `scripts/deploy_to_186.py`）将开发机本地包含测试数据（`bob`、`alice`、`charlie`、测试空间与“博世电钻”等物品）的 `server/data/items.db` 与开发测试多媒体文件打包上传到了生产/测试服务器，导致用户部署新服务后“开箱即脏”。
2. **更换服务器 IP / 重新部署后客户端缓存未自动自愈**：移动端本地离线数据库（`cached_items`）及空间快照仅按 `user_id` 分桶，缺少服务端实例世代标识。当服务器重新初始化、更换主机或 IP 时，如果新库与旧库用户 ID 重合（例如均为 ID=2），手机端 Cache-First 水合机制会直接读出旧环境的残留脏数据（如博世电钻），且当云端返回 0 件物品时不会主动清空本地脏缓存，严重依赖用户去系统设置手动清除应用数据。

## What Changes

- **部署流程与初始数据纯净化**：
  - 改造部署与打包流程，严禁打包上传任何开发机本地的 `*.db`、`*.db-wal`、`*.db-shm` 以及测试多媒体文件。
  - 规范服务初始化体系：生产环境首次启动仅通过 `init_db()` 创建数据表、单个默认 Admin 账号与 14 套通用分类模板，物品与空间严格保持零数据状态（0 用户、0 房屋、0 物品）。
  - `seed_data.py` 严格转为纯本地开发调试专用脚本，禁止在正式或自动化部署环境中被触发。
- **服务端数据库实例指纹（`server_instance_id`）体系**：
  - 服务端在数据库初建时自动生成并持久化全局唯一的实例 UUID（`server_instance_id`），并通过 `GET /health`、`GET /api/health` 及 `GET /api/auth/config` 对外暴露。
- **移动端服务实例感知与自动缓存自愈**：
  - 移动端 `NetworkRouteManager` 与 `ApiService` 在探测握手时比对 `server_instance_id`。
  - **同服 IP 变更（同一数据库）**：指纹匹配，平滑更新网络路由并保留本地会话与离线缓存。
  - **异服切换或服务重置（不同数据库）**：指纹不匹配时，客户端代码自动触发清理序列——清空本地 SQLite 缓存（`cached_items`）、清空空间元数据快照（`MetaSnapshotStore`）、清空多媒体磁盘缓存、注销失效 Token，并安全重置至登录页，杜绝旧数据残留。
- **空列表响应主动覆盖防护**：
  - 当首页拉取到云端物品总数为 0 时，显式清除本地对应范围的脏缓存，彻底消除幽灵数据残留。

## Capabilities

### Modified Capabilities
- `admin-user-governance`: 补充系统部署与初始化纯净性规范，确保初建库仅包含系统管理员与分类模板，严禁混入预置测试空间与物品。
- `mobile-auth-and-lan-discovery`: 增加服务端实例指纹（`server_instance_id`）握手与持久化要求，定义异服连接时的自动会话注销与本地缓存自动重置行为。
- `mobile-sync-and-concurrency-guard`: 增加基于服务器实例指纹的离线数据隔离要求，以及云端空列表响应时主动清理本地对应范围脏缓存的规则。

## Impact

- **部署脚本与容器配置 (`scripts/`, `docker-compose.yml`)**：
  - 调整 `scripts/deploy_to_186.py` 打包过滤规则，排除本地数据库与测试媒体目录。
- **服务端 (`server/`)**：
  - `app/db/init_db.py`：持久化 `server_instance_id`。
  - `app/main.py` 与 `app/api/auth.py`：在健康检查与配置接口中输出 `server_instance_id`。
- **移动端 (`mobile/`)**：
  - `lib/core/offline_db.dart`：支持整库清理与范围清理方法。
  - `lib/core/meta_snapshot_store.dart`：支持快照清空。
  - `lib/core/network_route_manager.dart` 与 `lib/core/api_service.dart`：集成实例指纹握手比对与自动注销清理联动。
  - `lib/screens/home_screen.dart`：空响应时主动清理脏缓存。
- **Web 端 (`web/`)**：
  - 检查服务端实例指纹，实例变更时自动注销并清空本地存储。

