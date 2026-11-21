# Spec Delta

## ADDED Requirements

### Requirement: Server Instance Fingerprint Handshake and Auto-Reset
移动端在与服务器握手或探测时 SHALL 获取并比对服务端的 `server_instance_id`。当检测到 `server_instance_id` 发生变更（连接到了不同的服务器实例或重置后的数据库）时，移动端 SHALL 自动注销旧的认证凭据，清空本地离线业务数据与多媒体缓存，重置会话并导航至登录页，绝不依赖用户手动清除应用数据。

#### Scenario: 相同服务器 IP 变更不影响登录态
- **WHEN** 移动端切换网络或服务器因 DHCP 更换局域网 IP，但 `server_instance_id` 保持一致
- **THEN** 移动端自动切换路由地址，保持当前用户登录态与本地离线缓存不变

#### Scenario: 连接到新服务器实例自动重置本地状态
- **WHEN** 移动端连接到的服务端返回了与本地记录不一致的 `server_instance_id`
- **THEN** 移动端自动清空本地会话与离线缓存，并安全跳转至登录页提示已连接至新服务实例

