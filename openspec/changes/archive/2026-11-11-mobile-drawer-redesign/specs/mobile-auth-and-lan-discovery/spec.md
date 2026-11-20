## Purpose

定义移动端纯净账密登录与受服务端开关控制的公开注册界面、内外网双地址智能路由与故障容灾切换机制，以及 Python 后端与 Flutter 移动端端到端的 mDNS 局域网自动发现能力。

## ADDED Requirements

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
移动端 SHALL 支持分别配置家庭内网（WiFi）与互联网外网服务器地址，在运行时自动优选健康通道，并在登录页与全局顶栏实时呈现当前线路状态。

#### Scenario: 蜂窝网络快轨与 WiFi 双轨并发竞速选线
- **WHEN** 设备切换至蜂窝移动网络且配置的内网地址为私有局域网 IP
- **THEN** 路由管理器 SHALL 跳过内网探测并直接切换至外网服务器地址
- **WHEN** 设备连接至 WiFi 或以太网
- **THEN** 路由管理器 SHALL 并发探测内网与外网健康接口（局域网优先），在内网健康时优先启用内网通道，业务请求遇内网超时时自动容灾回退至外网

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
