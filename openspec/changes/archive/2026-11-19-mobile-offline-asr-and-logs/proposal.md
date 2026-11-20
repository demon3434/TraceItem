## Why

国内 Android 机型（如荣耀 MagicOS）普遍未向第三方应用开放标准 `RecognitionService`，导致依赖系统原生 STT 的 `speech_to_text` 无法稳定使用；同时，现有的「系统诊断日志 🛠️」页面尚未收集语音识别全链路状态，真机排查困难。为在玩客云（ARMv7 / 1GB 内存）零推理算力开销的前提下彻底补齐中文高精度语音识别能力，需要引入**家庭服务器静态托管 + 手机端侧 `sherpa_onnx` 多模型自由下载与切换**方案，并完善移动端诊断日志模块。

## What Changes

- **家庭服务端（零算力静态模型托管）**：
  - 在 `server/app/core/config.py` 新增 `/data/models/asr` 目录配置，并在 `server/app/api/` 新增 `asr.py` 路由提供 `GET /api/asr/models`（返回可用模型清单、大小、类型、SHA256 与服务端就绪状态）与 `GET /api/asr/models/{model_id}/download`（流式下发模型压缩包）。玩客云仅作静态文件 HTTP 分发，不加载任何 ASR 模型推理。
- **手机端多模型管理与下载（设置页 + 首次引导）**：
  - 在 `mobile/pubspec.yaml` 引入 `sherpa_onnx: ^2.0.1` 与归档解压依赖（如 `archive`），新增 `AsrModelManager` 管理模型元数据、局域网断点/进度下载、SHA256 校验、本地缓存清理与当前引擎持久化选择。
  - 在 `SettingsScreen` 新增「语音识别模型 🎙️」子页面（`voice_model_settings_screen.dart`），支持查看模型详情、下载进度、一键切换当前启用模型（`SenseVoiceSmall int8` 高精度整句 / `Streaming Zipformer zh-en int8` 轻量流式 / 系统原生 STT）及清理本地模型缓存。
  - 首页首次点击语音搜索且尚未下载离线模型时，通过统一样式 `ShadSheet` / `ShadDialog` 引导用户选择模型并从家庭服务器下载。
- **手机端侧多引擎语音识别运行时**：
  - 抽离 `AsrEngineService` 封装 `sherpa_onnx` 的 `OfflineRecognizer`（SenseVoiceSmall 整句高精度）与 `OnlineRecognizer`（Streaming Zipformer 实时流式），配合 `record` 采集 16kHz 单声道 PCM 音频，并保持 `VoiceSearchOverlay`“点击进语音模式 → 底部大按钮按住说话、松开搜索、上滑取消”交互不变。
- **日志模块完善**：
  - 将语音引擎初始化、模型下载/校验、识别耗时与错误全链路接入 `AppLogger.instance`（新增 `VOICE` / `ASR` 级别标签）。
  - 增强 `DebugLogScreen`，支持按日志级别筛选（全部 / ERROR / WARN / VOICE / NET / MEDIA），保持与 `NutHollow` 一致的终端诊断体验。
- **UI 组件与规范确认**：全端交互弹窗、确认框与提示统一采用 `ShadDialog`、`ShadSheet`、`ShadButton` 与 `CustomDialogs.showToast` / `CustomDialogs.showConfirm`，图标 100% 使用 Lucide Icons，严禁任何原生 `alert` / `confirm` / 系统裸弹窗。

## Capabilities

### New Capabilities
- `mobile-offline-asr-models`: 家庭服务器零算力 ASR 模型静态托管、手机端多模型按需下载/校验/缓存管理、以及基于 `sherpa_onnx` 的多引擎端侧离线语音识别能力。

### Modified Capabilities
- `mobile-voice-search`: 将语音识别底层从单一系统 STT 扩展为支持“多模型端侧离线 ASR 优先 + 系统 STT 可选切换”的可插拔架构，并补充未下载模型时的引导下载流程与全链路诊断日志。

## Impact

- 服务端：`server/app/core/config.py`、`server/app/api/asr.py`、`server/app/api/__init__.py`、`server/app/services/asr_model_catalog.py`
- 移动端：
  - `mobile/pubspec.yaml`
  - `mobile/lib/core/app_logger.dart`、`mobile/lib/screens/settings/debug_log_screen.dart`
  - `mobile/lib/core/asr_model_manager.dart`、`mobile/lib/core/asr_engine_service.dart`
  - `mobile/lib/screens/settings/settings_screen.dart`、`mobile/lib/screens/settings/voice_model_settings_screen.dart`
  - `mobile/lib/widgets/voice_search_overlay.dart`、`mobile/lib/screens/home_screen.dart`
- 说明：本变更专注语音识别与日志模块，自然语言分词/停用词提纯检索留待后续独立变更实施。

