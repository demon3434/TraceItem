## Context

动机与背景见 `proposal.md`（Why）。当前 `VoiceSearchOverlay`（181 行）已具备 `SpeechToText` 初始化与呼吸动画 UI，但存在以下技术约束与现状：
- `HomeSearchBar` 位于 `mobile/lib/widgets/home_filter_sheets.dart`（406 行），目前仅绑定 `onTap`，未传递长按起止与垂直位移事件；
- `HomeScreen` 位于 `mobile/lib/screens/home_screen.dart`（482 行），接近项目 500 行单文件红线，需严格控制新增代码行数，避免突破上限；
- 受众以国内 Android 用户（如荣耀 MagicOS）为主，遵循 [ADR 0004](../../../docs/adr/0004-client-native-speech-to-text-and-fts5.md) 零服务端算力开销原则，同时需应对部分国产 ROM 未向第三方开放 `android.speech.RecognitionService` 的现实限制。

## Goals / Non-Goals

**Goals:**
- 打通 `HomeSearchBar` 长按 → `VoiceSearchOverlay` 实时转写/取消态切换 → 松手 `finish()`/`cancel()` 的完整手势闭环；
- 显式指定中文听写语言（`zh_CN`，兼容系统可用 locale 回退）；
- 实现国内 Android 系统 STT 不可用时的平滑兜底（自动关闭浮层 + 搜索框 `FocusNode` 拉起键盘 + `CustomDialogs.showToast` 引导）；
- 统一 `VoiceSearchOverlay` 使用 Lucide Icons 与当前主题色板（`ThemeController.instance.current`），并补充 iOS 语音识别权限描述。

**Non-Goals:**
- 本次不引入端侧离线 ASR 模型（如 `sherpa_onnx` Flutter 包），以保持安装包轻量与零模型下载门槛；
- 不修改服务端 FTS5 分词或自然语言停用词过滤逻辑。

## Decisions

### 1. 手势驱动方式：在 `HomeSearchBar` 捕获长按轨迹并联动 `VoiceSearchOverlay` 状态
- **选择**：在 `HomeSearchBar` 的麦克风按钮上使用 `GestureDetector` 的 `onLongPressStart`、`onLongPressMoveUpdate`、`onLongPressEnd`、`onLongPressCancel` 与 `onTap`，通过回调通知 `HomeScreen`；`HomeScreen` 使用 `GlobalKey<VoiceSearchOverlayState>`（或受控属性 `isCancelling`）驱动浮层取消态切换及 `finish()` / `cancel()` 调用。
- **理由**：用户手指在按住麦克风按钮期间并未抬起，浮层本身虽覆盖全屏，但原始指针焦点仍绑定在触发长按的 `HomeSearchBar` 按钮的 `GestureDetector` 上。由 `onLongPressMoveUpdate` 监测 `details.localOffsetFromOrigin.dy < -60` 是 Flutter 最稳妥的单指连贯交互方案。
- **替代方案**：在浮层上监听指针事件。但浮层是在按下后才插入 Widget 树的，无法直接接管已经开始的按压手势流，因此不可行。

### 2. 系统 STT 不可用降级策略（方案 C）
- **选择**：在 `VoiceSearchOverlay` 的 `_initAndStartListening()` 中，若 `_speech.initialize()` 返回 `false`（或抛出异常），立即触发 `widget.onUnavailable()` 回调。`HomeScreen` 收到回调后关闭 `_showVoiceOverlay`，延迟一帧调用 `_searchFocusNode.requestFocus()` 拉起系统键盘，并调用 `CustomDialogs.showToast(...)` 提示使用输入法语音输入。
- **理由**：国产输入法（讯飞、百度、搜狗、荣耀自带输入法）普遍内置高精度中文语音输入，且零包体增量；对支持系统 `RecognitionService` 的机型则保持一键长按零门槛直达。
- **替代方案**：直接弹窗报错停留在原处，或立即集成 50MB+ 离线 ASR 模型。前者体验断裂，后者过度增加 APK 体积。

### 3. 单文件行数控制（< 500 行红线）
- **选择**：`home_screen.dart` 当前为 482 行，剩余空间仅 18 行。将语音浮层的状态协调与不可用降级提示尽量封装在 `VoiceSearchOverlay` 或独立辅助逻辑中，`HomeScreen` 仅保留极简的 `_searchFocusNode`、`_voiceOverlayKey` 与少量回调转发，确保修改后 `home_screen.dart` 严格保持在 500 行以内。

### 4. 中文 Locale 选择策略
- **选择**：初始化成功后优先匹配 `zh_CN`（或 `zh-CN`）传入 `_speech.listen(localeId: ...)`；若设备 locales 列表为空或无匹配项，则回退传 `null` 由系统默认语言接管，避免部分国产 ROM 因严格校验 locale 字符串格式而拒绝识别。

## Risks / Trade-offs

- **[Risk] 部分国产 ROM（如荣耀 MagicOS）可能未向第三方 App 开放 `RecognitionService`** → 通过方案 C 自动拉起输入法键盘 + Toast 引导，确保用户不会卡死在无响应的录音浮层中；后续若真机反馈普遍不可用，可再评估按需下载端侧离线 ASR 模型。
- **[Risk] `onLongPressStart` 默认约有 500ms 触发延迟，老人/孩子可能刚按住就开始说话导致丢字** → 浮层弹出瞬间提供明确视觉与 `HapticFeedback.mediumImpact()` 触觉反馈，提示“开始说话”；`VoiceSearchOverlay` 保留极短的初始化过渡提示。
- **[Risk] `home_screen.dart` 接近 500 行红线** → 编码后强制检查 `home_screen.dart` 行数，若接近或超过 495 行，将语音控制或搜索栏组装逻辑进一步下沉到 `voice_search_overlay.dart` / `home_filter_sheets.dart`。

