## Context

动机与背景见 `proposal.md`（Why）。当前项目具备以下现状与约束：
- 家庭服务端（玩客云，ARMv7 / 1GB 内存）必须保持零 ASR 推理负载，仅负责静态文件托管；
- 移动端 `mobile/lib/core/app_logger.dart` 与 `mobile/lib/screens/settings/debug_log_screen.dart` 已存在，但尚未接入语音模块全链路日志，也缺少按级别筛选能力；
- `mobile/lib/widgets/voice_search_overlay.dart`（440 行）与 `mobile/lib/screens/home_screen.dart`（460 行）均接近 500 行单文件红线，因此本次**必须**将模型下载管理、端侧推理封装与设置子页面拆分为独立模块化文件，严禁突破 500 行限制。

## Goals / Non-Goals

**Goals:**
- 在服务端新增零算力 `/api/asr/models` 清单与 `/api/asr/models/{model_id}/download` 流式文件托管接口；
- 在移动端引入 `sherpa_onnx: ^2.0.1`，实现 `SenseVoiceSmall (int8)`（`OfflineRecognizer`）与 `Streaming Zipformer (int8)`（`OnlineRecognizer`）以及系统原生 `speech_to_text` 的统一抽象与自由切换；
- 在「设置 → 语音识别模型」页面及首页首次语音触发时，提供可视化模型下载进度、SHA256 校验、切换与缓存清理；
- 将语音识别与下载全链路接入 `AppLogger`，并在 `DebugLogScreen` 增加级别筛选胶囊。

**Non-Goals:**
- 本次不修改服务端 SQLite FTS5 查询与自然语言口语分词提纯逻辑（留作下一阶段变更）；
- 不在服务端提供模型训练或在线转换功能，模型压缩包由部署脚本或管理员放入 `/data/models/asr/` 目录即可被自动发现。

## Decisions

### 1. 服务端模型托管格式与路径
- **选择**：在 `settings.DATA_DIR / "models" / "asr"` 下按 `<model_id>.tar.gz`（或 `.tar.bz2`）存放模型归档，由 `AsrModelCatalog` 服务扫描文件是否存在及计算/缓存 SHA256，通过 FastAPI `StreamingResponse` 分块下发（chunk = 256KB）。
- **理由**：单文件归档下载避免手机端并发请求多个分散小文件（`tokens.txt`、`model.int8.onnx` 等）导致局部缺失，且流式分块发送对玩客云 1GB 内存占用几乎为零（< 2MB）。

### 2. 手机端侧音频采集与 `sherpa_onnx` 集成方式
- **选择**：复用项目已有的 `record: ^5.1.2` 插件（`AudioRecorder().startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1))`）采集 16kHz 单声道 PCM 字节流，转换为 `Float32List`（`sample / 32768.0`）喂给 `sherpa_onnx`：
  - **Streaming Zipformer**：每收到音频块即喂入 `OnlineStream.acceptWaveform`，持续 `decode` 并实时刷新 UI 文本；
  - **SenseVoiceSmall**：录音期间累积 PCM 采样缓冲，松手时一次性创建 `OfflineStream` 解码整句（荣耀 500 Pro 上约 0.2~0.4 秒），兼顾高精度与标点恢复。
- **理由**：`record` 已在 Android/iOS 权限与原生桥接中稳定运行，避免再引入额外的录音插件产生冲突。

### 3. 引擎抽象与单文件 < 500 行拆分
- **选择**：
  - `mobile/lib/core/asr_model_manager.dart`：负责模型元数据、Dio 进度下载、归档解压（`archive` 包）与 `SharedPreferences` 引擎偏好持久化（< 250 行）；
  - `mobile/lib/core/asr_engine_service.dart`：封装 `sherpa_onnx` 初始化、流式/离线解码与生命周期释放（< 250 行）；
  - `mobile/lib/screens/settings/voice_model_settings_screen.dart`：设置页多模型管理界面（< 300 行）；
  - `VoiceSearchOverlay` 仅负责 UI 与手势，通过 `AsrEngineService` 统一驱动识别，确保所有文件严格 < 500 行。

### 4. 日志模块增强
- **选择**：在 `AppLogger` 新增 `voice(String tag, String message)` 方法（级别为 `VOICE`），并在 `DebugLogScreen` 顶部增加水平滚动筛选胶囊（`ALL` / `VOICE` / `ERROR` / `WARN` / `NET` / `MEDIA`），支持过滤后一键复制。

## Risks / Trade-offs

- **[Risk] 玩客云 `/data/models/asr/` 初始可能尚未放入模型文件** → `/api/asr/models` 返回 `available_on_server: false` 状态，设置页与引导弹窗明确提示“服务端暂未放置该模型文件（路径：`/data/models/asr/`）”，并保留系统 STT 作为兜底选项，绝不静默卡死。
- **[Risk] 230MB 模型解压在主线程执行会卡顿 UI** → 使用 Dart `Isolate.run(...)` 在后台 Isolate 执行 `tar.gz`/`tar.bz2` 解压与 SHA256 校验，保持 UI 动画 60fps 流畅。
- **[Risk] `sherpa_onnx` 在部分 Android 机型上的 ABI 体积** → 严格遵循项目 `arm64-v8a` 单架构 Release 构建规范，仅打包 ARMv8 原生 `.so`。

