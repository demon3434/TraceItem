# Proposal

## Why

移动端在内网使用后离家进入公网环境（如蜂窝移动网络或外部 WiFi + 公网 WAF 反代）重新打开 App 时，顶栏会持续停留在路由器（内网）图标而无法自动切换至外网线路，并在一段时间后意外自动退出登录。根本原因在于前后台恢复存在 5 分钟探测冷却盲区、冷启动首页请求抢跑内网地址、外网/WAF 健康探测超时过严（1200ms/1500ms）导致回退失效，以及对非预期来源（如外部局域网同 IP 设备或未确认服务身份的网关）返回的 HTTP 401 一刀切触发登出。

## What Changes

- **前后台恢复与冷启动路由校准**：移除 `MainShellScreen` 切回前台时 `>= 5 分钟` 才重探路由的冷却限制，改为每次 `AppLifecycleState.resumed` 均执行轻量路由校准；在 `MainShellScreen` 启动及恢复时优先完成蜂窝快轨/初始路由判定后再触发首页数据拉取，避免首页请求卡死在不可达的内网地址上。
- **公网/WAF 健康探测容忍度与兜底增强**：参考 `NutHollow` 的双轨探测设计，为外网探针配置独立且更充裕的连接与响应超时（如 `3000ms~3500ms`），保留内网短超时（`1000ms~1200ms`）以维持局域网极速优先，并在 `/api/health` 与 `/health` 之外支持根路径兜底连通性校验，消除公网 TLS 握手与 WAF 转发导致的误判。
- **业务请求网络容灾异常全覆盖**：在 `ApiService` 的 `isTimeoutOrNet` 容灾判定中补齐 `DioExceptionType.sendTimeout` 与 `DioExceptionType.unknown`（含底层 `SocketException`），当内网私有地址请求失败且存在可用外网地址时自动容灾切换并重放幂等请求。
- **401 误杀防护与鉴权归属校验**：当请求发往私有内网地址返回 HTTP 401 时，不再无条件立即登出，而是先校验外网通道可用性或尝试回退外网重试（防止外部 WiFi 同 IP 网关/设备返回的 401 误清本地登录态）；仅在确认来自 TraceItem 后端的真实鉴权失效（且非可容灾的旧内网残留请求）时，才清理凭证并调用 `CustomDialogs.showToast`（严禁任何原生 `alert`/`confirm`）引导重新登录。
- **UI 组件约束确认**：顶栏线路状态仍由 `MainTopBar`（基于 `ShadPopover` 与 Lucide Icons）呈现，异常提示统一通过 `CustomDialogs.showToast` / `ShadDialog` 展示，全程零原生 `alert`/`confirm`。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mobile-auth-and-lan-discovery`: 增强「内外网双路由切换与顶栏实时探测浮层」与「认证凭据安全存储与多用户本地态隔离」需求，补充前后台恢复即时路由校准、公网 WAF 探针超时容忍度、网络容灾异常全覆盖及防外部局域网 401 误杀登出机制。

## Impact

- **移动端核心网络与路由**：
  - `mobile/lib/core/network_route_manager.dart`（探针超时分离、根路径兜底、启动时立即读取当前网络状态、防并发锁与状态幂等）
  - `mobile/lib/core/api_service.dart`（容灾异常类型补全、私有内网 401 防误杀回退重试逻辑）
  - `mobile/lib/screens/main_shell_screen.dart`（移除 5 分钟恢复冷却、优化冷启动路由与首页加载时序）
- **现有测试与文档**：需补充移动端路由管理器与 `ApiService` 容灾/401 防护单元测试，不涉及后端 API 变更与数据库迁移。

