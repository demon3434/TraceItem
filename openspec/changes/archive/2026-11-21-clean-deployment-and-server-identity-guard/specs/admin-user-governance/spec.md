# Spec Delta

## ADDED Requirements

### Requirement: Zero-Pollution Fresh Deployment
在全新部署或首次启动数据库初始化时，系统 SHALL 仅创建唯一的系统管理员账号（`admin`）并注入系统预设分类模板，严禁自动创建任何测试用户、测试房屋、测试房间或测试物品，保持普通用户空间与物品列表绝对纯净。

#### Scenario: 首次启动数据库纯净状态
- **WHEN** 全新启动服务并执行数据库初始化
- **THEN** 数据库仅包含默认管理员账号与预设分类模板，普通用户列表、房屋列表与物品列表均为空（count 为 0）

### Requirement: Server Instance Fingerprint Persistence
系统 SHALL 在首次初始化数据库时生成并持久化全局唯一的数据库实例指纹（`server_instance_id` UUID），并在基础健康检查与系统公开配置端点中输出该指纹，且只要物理数据库未被删除重建，该指纹保持不变。

#### Scenario: 健康检查返回实例指纹
- **WHEN** 客户端请求 `GET /health`、`GET /api/health` 或 `GET /api/auth/config`
- **THEN** 响应体中包含持久化的非空 `server_instance_id` 字符串字段

