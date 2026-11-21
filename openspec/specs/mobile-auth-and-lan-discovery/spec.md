# mobile-auth-and-lan-discovery Specification

## Purpose

定义移动端纯净账密登录与受服务端开关控制的公开注册界面、内外网双地址智能路由与故障容灾切换机制，以及 Python 后端与 Flutter 移动端端到端的 mDNS 局域网自动发现能力。

## Requirements

### Requirement: 纯净账密登录与受控公开注册
移动端登录页 SHALL 要求用户显式输入账号和密码，严禁保留快捷登录按钮或默认预填凭证，并根据服务端配置动态开放注册操作界面。

#### Scenario: 无快捷登录表单与非 Admin 拦截提示
- **WHEN** 用户打开移动端登录页面
- **THEN** 账号与密码输入框 SHALL 默认为空，且页面不渲染任何内置测试账号快捷填充按钮
- **WHEN** 使用 `admin` 角色账号在当前非 Admin 阶段登录
- **THEN** 系统 SHALL 弹出 `ShadDialog` 提示请前往电脑 Web 端管理后台，并阻止进入普通成员工作区

#### Scenario: 根据服务端配置动态展示注册入口并完成注册
- **WHEN** 登录页已配置或自动发现有效的服务器地址
- **THEN** 系统 SHALL 请求 `GET /api/auth/config`；当 `allow_public_registration` 为 `true` 时展示「账号登录 / 注册新账号」Tab 切换，为 `false` 时隐藏注册入口
- **WHEN** 用户在注册界面提交账号、昵称与密码
- **THEN** 系统 SHALL 调用 `POST /api/auth/register` 创建账号并在成功后自动登录进入工作区

### Requirement: 内外网双路由切换与顶栏实时探测浮层
移动端 SHALL 支持分别配置家庭内网与互联网外网服务器地址，在冷启动、前后台恢复、网络拓扑切换及业务请求超时场景下自动优选健康通道，并在登录页与全局顶栏实时呈现当前线路状态。

#### Scenario: 蜂窝网络快轨与 WiFi 双轨并发竞速选线
- **WHEN** 设备切换至蜂窝移动网络且配置的内网地址为私有局域网 IP
- **THEN** 路由管理器 SHALL 跳过内网探测并直接切换至外网服务器地址
- **WHEN** 设备连接至 WiFi 或以太网
- **THEN** 路由管理器 SHALL 并发探测内网（短超时快速判定）与外网（兼容公网 TLS 与 WAF 反代延迟）健康接口，内网健康时优先启用内网通道，否则自动切换至外网通道

#### Scenario: 前后台恢复即时校准路由且避免冷启动抢跑
- **WHEN** 应用从后台恢复至前台（无论后台停留时长是否超过 5 分钟）或首次进入主工作区
- **THEN** 系统 SHALL 立即触发路由校准并优先完成蜂窝快轨或双轨选线，再发起首页核心数据拉取，避免业务请求长时间阻塞在不可达的旧内网地址上

#### Scenario: 业务请求遇内网异常自动容灾回退至外网
- **WHEN** 当前激活线路为私有内网地址，且业务请求发生连接超时、发送超时、接收超时或底层网络连接异常
- **THEN** 网络客户端 SHALL 自动切换至已配置的外网地址并重放幂等请求，同时更新顶栏线路图标为外网通道

#### Scenario: 顶栏路由图标与手动内网探测浮层
- **WHEN** 用户处于已登录工作区
- **THEN** 顶栏右侧 SHALL 根据当前线路动态显示路由器图标（内网）、地球图标（外网）或断网图标
- **WHEN** 用户点击顶栏线路状态图标
- **THEN** 系统 SHALL 弹出 `ShadPopover` 展示当前线路类型、物理服务地址、探测状态，并提供「尝试连接内网通道」手动测速切换按钮

#### Scenario: 登录页底部双态服务地址配置入口
- **WHEN** 登录页尚未配置任何服务器地址
- **THEN** 页面底部 SHALL 展示醒目的引导卡片提示点击配置内外网地址
- **WHEN** 已配置服务器地址
- **THEN** 页面底部 SHALL 展示当前激活线路胶囊（局域网/互联网及地址摘要），点击可打开双路配置弹窗

### Requirement: 端到端 mDNS 局域网服务发现与健康检查兼容
服务端与移动端 SHALL 基于 mDNS（`_traceitem._tcp.local.`）实现零配置局域网自动发现，并保证健康探测接口路径前后端完全兼容。

#### Scenario: 服务端兼容健康检查路由并异步广播 mDNS
- **WHEN** FastAPI 服务端启动完成
- **THEN** 服务 SHALL 同时在 `GET /health` 与 `GET /api/health` 返回 HTTP 200 健康响应
- **THEN** 服务 SHALL 异步启动 `_traceitem._tcp.local.` mDNS 广播，智能过滤 Docker 内部 `172.x` 网桥 IP 并支持通过 `SERVICE_ADVERTISE_HOST` 与 `SERVICE_ADVERTISE_PORT` 指定宿主机通告地址与端口

#### Scenario: 移动端自动发现局域网服务端
- **WHEN** 用户在登录页服务配置或系统设置「内外网地址配置」子页触发「自动发现内网服务」（或在未配置地址的登录页首次进入局域网）
- **THEN** 移动端 SHALL 在局域网内扫描 `_traceitem._tcp` 服务广播，解析出 `http://<host>:<port>` 后自动填入内网地址输入框并反馈扫描状态

### Requirement: 认证凭据安全存储与多用户本地态隔离
移动端 SHALL 使用系统安全存储保存认证令牌，按 `user_id` 隔离个人主题偏好与用户态缓存，在真实会话失效时清理内存残余，并防止外部局域网非目标服务误触发登出。

#### Scenario: 登录凭据安全落盘与兼容迁移
- **WHEN** 用户成功登录或应用启动初始化会话
- **THEN** 移动端 SHALL 使用 `flutter_secure_storage` 读写 `auth_token`；若检测到旧版明文 `SharedPreferences` 存在历史 `auth_token`，SHALL 自动迁移至安全存储并删除明文键

#### Scenario: 私有内网请求遇 401 时优先容灾校验防止误登出
- **WHEN** 请求发往私有内网地址并收到 HTTP `401 Unauthorized`，且设备已配置外网服务器地址
- **THEN** 网络客户端 SHALL 先尝试将线路容灾切换至外网地址并重放该请求；仅当外网通道同样返回 `401`（或未配置外网通道且确认为真实鉴权失效）时，才判定会话失效并执行登出

#### Scenario: 退出登录清理内存状态与图片诊断缓存
- **WHEN** 用户主动退出登录或因真实会话失效被动登出
- **THEN** 移动端 SHALL 清除安全存储中的 `auth_token` 与当前用户信息，清空 `PaintingBinding.instance.imageCache` 内存图片缓存与 `AppLogger` 运行时日志，弹出统一 `CustomDialogs.showToast` 提示（严禁原生 `alert`/`confirm`），并重建路由至 `LoginScreen`

#### Scenario: 按用户隔离主题偏好且保留设备级网络配置
- **WHEN** 同一台设备从用户 A 切换登录为用户 B
- **THEN** `ThemeController` SHALL 加载用户 B 独立的主题配色偏好（Key 含 `user_id`），而内外网服务器地址配置作为设备级设置保持保留

### Requirement: 服务端静态媒体访问鉴权
服务端媒体分发接口 SHALL 校验访问者的登录态合法性，防止未认证请求直接读取存储文件。

#### Scenario: 携带有效凭据访问媒体文件
- **WHEN** 客户端请求 `GET /api/media/file/{file_path:path}` 且通过 Header（`Authorization: Bearer <token>`）或合法鉴权参数提供有效 JWT
- **THEN** 服务端 SHALL 正常流式返回媒体文件并支持 Range 请求

#### Scenario: 未携带有效凭据访问媒体文件
- **WHEN** 未认证客户端请求 `GET /api/media/file/{file_path:path}`
- **THEN** 服务端 SHALL 返回 HTTP `401 Unauthorized` 拒绝访问

### Requirement: Web 端右上角统一设置入口与账号管理
Web 端顶部导航栏右上角 SHALL 提供统一的「设置」一级功能按钮，收纳主题切换与当前账号安全管理功能。

#### Scenario: 展开右上角设置菜单
- **WHEN** 用户点击 Web 端右上角「设置」一级图标按钮
- **THEN** 系统 SHALL 展开设置菜单，包含「切换主题」「修改密码」「修改昵称」「退出登录」四个入口

### Requirement: Server Instance Fingerprint Handshake and Auto-Reset
移动端在与服务器握手或探测时 SHALL 获取并比对服务端的 `server_instance_id`。当检测到 `server_instance_id` 发生变更（连接到了不同的服务器实例或重置后的数据库）时，移动端 SHALL 自动注销旧的认证凭据，清空本地离线业务数据与多媒体缓存，重置会话并导航至登录页，绝不依赖用户手动清除应用数据。

#### Scenario: 相同服务器 IP 变更不影响登录态
- **WHEN** 移动端切换网络或服务器因 DHCP 更换局域网 IP，但 `server_instance_id` 保持一致
- **THEN** 移动端自动切换路由地址，保持当前用户登录态与本地离线缓存不变

#### Scenario: 连接到新服务器实例自动重置本地状态
- **WHEN** 移动端连接到的服务端返回了与本地记录不一致的 `server_instance_id`
- **THEN** 移动端自动清空本地会话与离线缓存，并安全跳转至登录页提示已连接至新服务实例

#### Scenario: Web 端修改昵称即时生效
- **WHEN** 用户在设置菜单选择「修改昵称」并通过 `shadcn-vue` Dialog 提交新昵称
- **THEN** 前端 SHALL 调用 `PUT /api/auth/me` 更新昵称，刷新本地用户信息并弹出统一轻提示

#### Scenario: Web 端修改密码后立即失效旧会话并要求重登
- **WHEN** 用户在设置菜单选择「修改密码」并提交成功
- **THEN** 服务端 SHALL 递增 `token_version` 使所有既有会话失效，Web 前端 SHALL 清理本地 Token 与用户态并跳转登录页引导使用新密码重新登录

