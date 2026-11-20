# Spec Delta: shared-constants-ssot

## MODIFIED Requirements

### Requirement: 主题色板与系统预设常量三端同步
Web 端、Mobile 端与 Server 端 MUST 消费源自 `shared/` 的同一套多巴胺主题定义、14 套系统预设分类模板、多媒体规格参数与附件配额，确保多端视觉主题、新用户初始化分类、端侧压缩阈值及附件上限严格对齐，严禁在各端重复硬编码。

#### Scenario: 共享多媒体规格与附件配额三端一致
- **WHEN** 开发者在 `shared/media_limits.json` 中配置附件上限（图片 ≤9、视频 ≤3、音频 ≤3）、录制时长上限（视频 ≤60s、音频 ≤120s）、视频画质预设（360p、480p、720p、1080p）及默认缓存配额（200MB），并执行同步流程
- **THEN** Mobile 端与 Server 端自动生成的常量代码 SHALL 包含完全一致的限制参数，且双端在表单录入与服务端接口校验中强制执行相同配额。

#### Scenario: 多巴胺主题色板在双端保持一致
- **WHEN** 用户在 Web 端或 Mobile 端打开主题设置界面并切换任一多巴胺主题
- **THEN** 7 套核心多巴胺主题（阳光暖橙、草莓甜心、薄荷清柠、星空城堡、雅致原木、梦幻薰衣草、赛博霓虹）的名称、图标、描述及主辅色值在两端 SHALL 完全一致。

#### Scenario: 共享同步校验拦截未同步的生成代码
- **WHEN** 共享源文件被修改但未执行同步生成，导致目标端生成常量与共享源文件不一致时
- **THEN** 同步校验命令（`python scripts/sync_shared.py --check`）SHALL 返回非零错误并指出具体存在差异的目标文件。

