## Purpose

在家庭服务端（如玩客云）零推理算力开销的前提下，静态托管多款量化中文端侧 ASR 模型，并支持移动端按需下载、校验、自由切换运行引擎与本地缓存管理。

## ADDED Requirements

### Requirement: Server Static ASR Model Hosting
家庭服务端 SHALL 以纯静态文件分发方式托管端侧 ASR 模型，严禁在服务端加载或运行任何 ASR 推理进程。

#### Scenario: 客户端查询可用语音模型清单
- **WHEN** 移动端请求 `GET /api/asr/models`
- **THEN** 服务端 SHALL 返回支持的多模型清单（至少包含 `sensevoice_small_int8` 与 `streaming_zipformer_zh_en_int8`），每项包含模型 ID、展示名称、识别模式、适用说明、压缩包大小、SHA256 及服务端文件就绪状态。

#### Scenario: 客户端从家庭服务器流式下载模型包
- **WHEN** 移动端请求 `GET /api/asr/models/{model_id}/download` 且服务端已存放对应模型归档
- **THEN** 服务端 SHALL 以流式响应直接下发模型归档文件，不在服务端产生额外内存峰值或模型推理开销。

### Requirement: Mobile Multi-Model Management and Switching
移动端设置页 SHALL 提供「语音识别模型」管理页面，允许用户自主选择下载、切换运行或清理本地 ASR 模型，并实时展示下载与校验进度。

#### Scenario: 用户在设置页下载并启用指定离线模型
- **WHEN** 用户在「设置 → 语音识别模型」页面点击某个未下载模型（如 `SenseVoiceSmall` 或 `Streaming Zipformer`）的下载按钮
- **THEN** 应用 SHALL 从家庭服务器流式下载模型归档并展示实时进度条，完成 SHA256 校验与解压后将其标记为“已下载”并自动设为当前启用引擎。

#### Scenario: 用户在多个已下载模型或系统 STT 之间切换
- **WHEN** 用户在「设置 → 语音识别模型」页面点击切换至另一个已下载模型或“系统原生语音”
- **THEN** 应用 SHALL 立即持久化保存引擎偏好，并通过 `CustomDialogs.showToast` 提示切换成功，后续语音搜索立即生效。

#### Scenario: 用户清理本地已下载模型缓存
- **WHEN** 用户点击已下载模型的删除按钮并通过 `ShadDialog` 二次确认
- **THEN** 应用 SHALL 删除该模型占用的本地存储目录并释放空间，若当前正在使用该模型则自动回退到其他可用引擎或待下载状态。

### Requirement: Mobile Diagnostic Logging Enhancement
移动端诊断日志模块 SHALL 记录语音识别与模型下载全链路关键事件，并支持在「设置 → 系统诊断日志」页面按级别筛选与一键复制。

#### Scenario: 语音识别与模型下载事件写入诊断日志
- **WHEN** 应用执行模型清单拉取、模型下载校验、ASR 引擎初始化或语音识别（成功/失败）
- **THEN** 应用 SHALL 将对应状态、耗时与错误信息写入 `AppLogger` 诊断日志收集器，并在「系统诊断日志」页面实时可见。

#### Scenario: 用户在诊断日志页按级别筛选日志
- **WHEN** 用户在「系统诊断日志」页面点击级别筛选胶囊（如 `全部`、`VOICE`、`ERROR`、`NET`）
- **THEN** 日志列表 SHALL 即时过滤展示对应级别的日志条目，并支持一键复制筛选或全部日志。

