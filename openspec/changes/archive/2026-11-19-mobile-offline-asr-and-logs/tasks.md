## 1. 服务端静态 ASR 模型托管

- [x] 1.1 在 `server/app/core/config.py` 新增 `ASR_MODELS_DIR`（`/data/models/asr`）并在 `ensure_directories()` 自动创建；新建 `server/app/services/asr_model_catalog.py` 定义多模型目录元信息（`sensevoice_small_int8`、`streaming_zipformer_zh_en_int8`）与文件/SHA256 检测逻辑。验证：文件行数 < 500 行，服务端不引入任何推理依赖。
- [x] 1.2 新建 `server/app/api/asr.py` 并在 `server/app/api/__init__.py` 注册路由，提供 `GET /api/asr/models` 与 `GET /api/asr/models/{model_id}/download` 流式文件下载接口。验证：使用 FastAPI TestClient 验证清单接口返回结构与缺失文件 404 处理。

## 2. 移动端诊断日志模块增强

- [x] 2.1 在 `mobile/lib/core/app_logger.dart` 新增 `voice(String tag, String message)`（`VOICE` 级别）与按级别过滤辅助方法。验证：文件行数 < 500 行，`VOICE` 日志可正常记录与格式化。
- [x] 2.2 改造 `mobile/lib/screens/settings/debug_log_screen.dart`，在顶部增加多巴胺风格级别筛选胶囊（`ALL` / `VOICE` / `ERROR` / `WARN` / `NET` / `MEDIA`），支持过滤展示与一键复制当前筛选日志。验证：文件行数 < 500 行，无原生弹窗，图标 100% 使用 Lucide Icons。

## 3. 移动端多模型下载、管理与端侧 `sherpa_onnx` 引擎

- [x] 3.1 在 `mobile/pubspec.yaml` 引入 `sherpa_onnx: ^2.0.1`、`archive` 与 `crypto`（用于流式下载后的后台校验与解压），执行 `flutter pub get`。验证：依赖解析成功无版本冲突。
- [x] 3.2 新建 `mobile/lib/core/asr_model_manager.dart`：封装模型清单拉取、Dio 进度下载、后台 `Isolate` 解压与 SHA256 校验、本地缓存大小统计与删除、以及 `SharedPreferences` 引擎偏好读写，并将全链路事件写入 `AppLogger.instance.voice`。验证：文件行数 < 500 行。
- [x] 3.3 新建 `mobile/lib/core/asr_engine_service.dart`：基于 `sherpa_onnx` 与 `record`（16kHz 单声道 PCM 流）实现统一引擎调度，支持 `SenseVoiceSmall`（`OfflineRecognizer`）、`Streaming Zipformer`（`OnlineRecognizer`）与系统 `speech_to_text` 自由切换及资源释放，关键事件写入 `AppLogger.instance.voice`。验证：文件行数 < 500 行。

## 4. 设置页模型管理 UI 与首页语音搜索集成

- [x] 4.1 新建 `mobile/lib/screens/settings/voice_model_settings_screen.dart` 并在 `mobile/lib/screens/settings/settings_screen.dart` 注册 `SettingsSubPage.voiceModels`（「语音识别模型 🎙️」）：支持展示模型卡片、实时下载进度、一键切换当前引擎及 `ShadDialog` 确认清理本地模型。验证：两个文件行数均 < 500 行，全套使用 `shadcn_ui` 与 Lucide Icons，无原生弹窗。
- [x] 4.2 改造 `mobile/lib/widgets/voice_search_overlay.dart` 与 `mobile/lib/screens/home_screen.dart`：首次点击语音按钮若本地无离线模型则弹出 `ShadSheet` / `ShadDialog` 引导选择并下载；有模型时直接由 `AsrEngineService` 驱动当前选中引擎执行识别，保持“点击进语音模式 → 底部大按钮按住说话、松开搜索、上滑取消”交互。验证：`voice_search_overlay.dart` 与 `home_screen.dart` 均严格 < 500 行。

## 5. 静态检查与 ARMv8 Release 构建

- [x] 5.1 在 `mobile/` 运行 `flutter analyze` 与 `flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation`，并核查所有新增/修改文件行数 < 500 行。验证：`flutter analyze` 无 error，Release APK 成功生成。
