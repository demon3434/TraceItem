# Tasks

## 1. 服务端实例指纹与部署纯净化

- [x] 1.1 在服务端 `init_db.py` 中增加 `server_instance_id` UUID 生成与持久化逻辑，保证数据库初建时生成且生命周期绑定
- [x] 1.2 在 `main.py`（`/health`, `/api/health`）与 `auth.py`（`/api/auth/config`）中透出 `server_instance_id` 字段，并通过单元测试验证
- [x] 1.3 改造 `seed_data.py` 仅作为纯本地手动调试工具，禁止在正常启动流程中被任何逻辑引用
- [x] 1.4 改造 `scripts/deploy_to_186.py` 打包过滤规则，绝对排除开发机本地 `*.db*` 与测试媒体目录，仅保留必要的模型目录与源码

## 2. 移动端指纹握手与全自动缓存自愈

- [x] 2.1 在 `mobile/lib/core/offline_db.dart` 中实现 `clearAllCache()`、`clearUserCache()` 与 `clearScopeCache()` 缓存清理方法
- [x] 2.2 在 `mobile/lib/core/meta_snapshot_store.dart` 中实现 `clearAllSnapshots()` 与 `clearSnapshot()` 快照抹除方法
- [x] 2.3 在 `network_route_manager.dart` 与 `api_service.dart` 中持久化 `last_server_instance_id`，探测握手时比对指纹，指纹不符时自动执行重置序列
- [x] 2.4 在 `mobile/lib/screens/home_screen.dart` 中实现第 1 页为空响应时主动清理对应范围脏缓存，防止历史残留
- [x] 2.5 在 `api_service.dart` 的 `logout()` 流程中增加当前用户本地离线业务数据的主动清理

## 3. 部署交付、阿里云镜像推送与玩客云清理发布

- [x] 3.1 运行改造后的 `deploy_to_186.py` 部署到 186 玩客云测试环境，验证全新建库无任何测试数据（0 用户、0 房屋、0 物品）且健康接口输出指纹
- [x] 3.2 构建 `traceitem-app:latest` 并推送至阿里云个人容器镜像仓库（Aliyun Container Registry）
- [x] 3.3 在玩客云上清理历史旧持久化数据（清理历史旧数据库与测试媒体），拉取最新镜像重新启动容器
- [x] 3.4 在玩客云执行 `docker image prune -a -f` 清理过时悬空镜像，释放存储并验证线上 `/api/health` 与纯净空间状态
