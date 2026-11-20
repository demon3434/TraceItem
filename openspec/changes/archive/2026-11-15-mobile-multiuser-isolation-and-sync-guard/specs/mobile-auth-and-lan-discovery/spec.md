# Spec Delta

## ADDED Requirements

### Requirement: 认证凭据安全存储与多用户本地态隔离
移动端 SHALL 使用系统安全存储保存认证令牌，并按 `user_id` 隔离个人主题偏好与用户态缓存，在退出登录时彻底清理内存残余。

#### Scenario: 登录凭据安全落盘与兼容迁移
- **WHEN** 用户成功登录或应用启动初始化会话
- **THEN** 移动端 SHALL 使用 `flutter_secure_storage` 读写 `auth_token`；若检测到旧版明文 `SharedPreferences` 存在历史 `auth_token`，SHALL 自动迁移至安全存储并删除明文键

#### Scenario: 退出登录清理内存状态与图片诊断缓存
- **WHEN** 用户主动退出登录或因会话失效被动登出
- **THEN** 移动端 SHALL 清除安全存储中的 `auth_token` 与当前用户信息，清空 `PaintingBinding.instance.imageCache` 内存图片缓存与 `AppLogger` 运行时日志，并重建路由至 `LoginScreen`

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

#### Scenario: Web 端修改昵称即时生效
- **WHEN** 用户在设置菜单选择「修改昵称」并通过 `shadcn-vue` Dialog 提交新昵称
- **THEN** 前端 SHALL 调用 `PUT /api/auth/me` 更新昵称，刷新本地用户信息并弹出统一轻提示

#### Scenario: Web 端修改密码后立即失效旧会话并要求重登
- **WHEN** 用户在设置菜单选择「修改密码」并提交成功
- **THEN** 服务端 SHALL 递增 `token_version` 使所有既有会话失效，Web 前端 SHALL 清理本地 Token 与用户态并跳转登录页引导使用新密码重新登录

