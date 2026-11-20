# Tasks

## 1. 路由管理器探针分层与容灾强化

- [x] 1.1 优化 `mobile/lib/core/network_route_manager.dart` 的 `checkUrlHealthy` 与 `_runBestRouteProbe`：将每次探测的 `connectTimeout`、`sendTimeout`、`receiveTimeout` 显式传入请求 `Options`（内网维持 `1200ms`，外网放宽至 `3500ms` 以兼容公网 TLS 与 WAF 延迟），增加根路径 `/` 兜底探测，并在 `startAutoRouting` 启动时主动执行一次当前网络拓扑检查；验证文件行数严格 `< 500` 行，且 `flutter analyze mobile/lib/core/network_route_manager.dart` 无错误。
- [x] 1.2 为 `NetworkRouteManager` 补充单元测试（如 `mobile/test/network_route_manager_test.dart`），覆盖蜂窝快轨秒切、外网慢响应（>1.5s）探针成功切换与状态幂等行为，执行 `flutter test mobile/test/network_route_manager_test.dart` 全部通过。

## 2. 网络拦截器拆分与 401 防误杀容灾

- [x] 2.1 新建 `mobile/lib/core/api_route_interceptor.dart`（控制 `< 200` 行），从 `mobile/lib/core/api_service.dart` 抽离 Dio 请求/响应/错误拦截器；在 `isTimeoutOrNet` 中补全 `DioExceptionType.sendTimeout` 与 `DioExceptionType.unknown`（含 `SocketException`），并实现私有内网 `401` 防误杀机制：当请求发往私有内网地址返回 `401` 且已配置外网地址时，先回退外网并重放请求，仅在外网也返回 `401` 或无可用外网时才执行登出。
- [x] 2.2 更新 `mobile/lib/core/api_service.dart` 接入拆分后的 `ApiRouteInterceptor`，验证 `api_service.dart` 与 `api_route_interceptor.dart` 行数均严格 `< 500` 行，并编写 `mobile/test/api_route_interceptor_test.dart` 验证私有内网 401 回退重放成功时不登出、外网真实 401 时触发登出，执行 `flutter test mobile/test/api_route_interceptor_test.dart` 通过。

## 3. 主壳层生命周期即时校准与 UI 反馈验证

- [x] 3.1 修改 `mobile/lib/screens/main_shell_screen.dart`：移除 `didChangeAppLifecycleState` 中的 5 分钟恢复冷却门控，确保每次切回前台均触发 `detectAndSwitchBestRoute()`；优化 `initState` 冷启动时序，优先完成蜂窝快轨/初始路由判定并在路由发生变更时刷新首页数据；确认登出提示与线路浮层均使用 `CustomDialogs.showToast`、`ShadPopover`（零原生 `alert`/`confirm`）且保持原有主题色板 Tokens，验证文件行数 `< 500` 行。
- [x] 3.2 执行全量静态检查与移动端测试（`flutter analyze` 与 `flutter test`），并核对所有新建/修改 Dart 源文件行数均严格 `< 500` 行。
