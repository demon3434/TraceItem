# Design

## Context

当前问题的背景与触发路径见 `proposal.md - Why`。在代码层面，主要涉及以下三个核心模块以及一项代码规范硬约束：
1. `mobile/lib/core/network_route_manager.dart`（413 行）：负责内外网地址持久化、`connectivity_plus` 监听、双轨竞速探测与容灾回退。当前 `_probeDio` 全局 `connectTimeout` 写死为 `1200ms`，`checkUrlHealthy` 仅依次尝试 `/api/health` 与 `/health`，在公网 TLS + WAF 反代场景下极易超时失败。
2. `mobile/lib/core/api_service.dart`（498 行）：已逼近单文件 500 行硬性上限。当前 Dio `onError` 拦截器对任何非登录接口的 `401` 均无条件调用 `logout()`，且 `isTimeoutOrNet` 未覆盖 `sendTimeout` 与 `unknown`。
3. `mobile/lib/screens/main_shell_screen.dart`（217 行）：`initState` 异步触发路由探测但未协调 `HomeScreen` 首次拉取；`didChangeAppLifecycleState` 存在 5 分钟冷却门控，导致短时离家切网后回到前台不触发路由重探。

## Goals / Non-Goals

**Goals:**
- 消除“内网切公网”场景下的路由器图标滞留问题，确保冷启动、后台恢复、蜂窝/外部 WiFi 切换均能在 1~3.5 秒内稳定收敛至可用线路。
- 消除公网 WAF 反代与外部 WiFi 同 IP 设备引起的误登出，保证只有真实鉴权失效时才清理本地凭证并提示。
- 严格遵守单文件 `< 500 行` 约束，将 `ApiService` 的拦截器与容灾逻辑拆分为独立模块。

**Non-Goals:**
- 不引入 Refresh Token 双令牌机制（避免改动后端 `/api/auth/*` 协议与现有 30 天 JWT 体系）。
- 不引入原生 Android `ConnectivityManager.NetworkCallback` 平台通道代码（继续基于现有 `connectivity_plus` + 生命周期恢复校准实现跨端一致行为）。

## Decisions

### 1. 探针超时分层与 WAF 兼容性兜底
- **决策**：解除 `_probeDio` 全局 `1200ms` 的 `connectTimeout` 死锁，在 `checkUrlHealthy(rawUrl, timeoutMs: ...)` 中为每次请求通过 `Options` 独立传入 `connectTimeout`、`sendTimeout`、`receiveTimeout`。内网探针维持 `1200ms`，外网探针放宽至 `3500ms`。同时参考 `NutHollow`，在 `/api/health` 与 `/health` 之外允许按配置或兜底探测，并确保 `startAutoRouting()` 启动时主动拉取一次 `checkConnectivity()` 立即执行蜂窝快轨判定。
- **备选方案**：将内外网统一放宽到 `3500ms`。放弃原因：会导致在外部 WiFi 环境下等待私有 IP 超时过长，拖慢切外网速度。

### 2. 前后台恢复即时校准与冷启动防抢跑
- **决策**：移除 `MainShellScreen.didChangeAppLifecycleState` 中 `>= 5 分钟` 的时间门控，每次 `AppLifecycleState.resumed` 均调用 `NetworkRouteManager.instance.detectAndSwitchBestRoute()`（内部已有 `_inflightProbe` 互斥防重入）。当线路从内网切换到外网（或反之）时，通知 `HomeScreen` 刷新数据。冷启动时，`MainShellScreen` 可先执行极短的非阻塞快轨判定（蜂窝网络 0ms 同步切换），再让首页发起请求，避免首页 3 个并发请求卡在不可达内网 IP 上等待 15 秒。
- **备选方案**：每次 `resumed` 强制 `setState` 重建整个 `HomeScreen`。放弃原因：会丢失用户当前滚动位置与筛选状态；仅在路由实际发生切换或数据需要刷新时调用 `loadInitialData(keepSelection: true)` 体验更平滑。

### 3. `ApiService` 拦截器拆分与“内网 401 防误杀”机制
- **决策**：由于 `api_service.dart` 已达 498 行，将 Dio `InterceptorsWrapper` 逻辑抽离至独立文件 `mobile/lib/core/api_route_interceptor.dart`（控制在 150 行以内）。在拦截器中：
  1. `isTimeoutOrNet` 覆盖 `connectionTimeout`、`sendTimeout`、`receiveTimeout`、`connectionError` 及 `unknown`（当 `err.error` 为 `SocketException` 或连接类异常时）。
  2. **401 防误杀**：当收到 `401` 且请求打向的是私有内网地址（`NetworkRouteManager.isPrivateNetwork(reqBase)`）且尚未经过容灾重试（`!alreadyRetried`）且已配置 `_extranetUrl` 时，**不立即调用 `logout()`**，而是先调用 `fallbackToExtranetIfNeeded(reqBase)` 切换至外网并重放原请求；只有当外网重试仍返回 `401`，或未配置外网且非私有地址时，才执行 `logout()` 与 `onUnauthorized?.call()`。
- **备选方案**：要求后端在所有 401 响应头注入自定义标识。放弃原因：仍无法覆盖外部 WiFi 网关返回 401 后需要无缝切外网重放的场景，且需要改动后端。

## Risks / Trade-offs

- [每次 `resumed` 都触发探测可能增加少量 `/api/health` 请求] → `NetworkRouteManager` 已有 `_inflightProbe` 单飞互斥锁，且蜂窝网络下命中快轨不发任何内网探针，外网仅在处于内网或离线恢复时探测，开销极低。
- [内网 401 回退外网重放可能使真实过期的 Token 多一次外网请求延迟] → 仅在请求命中私有内网地址且尚未重试时多一次外网校验，最多增加 1 次 RTT（通常 < 500ms），即可彻底消除外部 WiFi 误登出风险，收益远大于代价。

