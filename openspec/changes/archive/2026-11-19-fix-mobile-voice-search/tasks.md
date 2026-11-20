## 1. 语音浮层与取消态视觉重构

- [x] 1.1 改造 `mobile/lib/widgets/voice_search_overlay.dart`：公开 `VoiceSearchOverlayState`，支持外部控制 `isCancelling` 取消态切换、`finish()` 与 `cancel()` 调用；将 `Icons.mic_rounded` 替换为 `LucideIcons.mic`（取消态显示 `LucideIcons.x` 与醒目红色警示渐变），适配 `ThemeController.instance.current` 多巴胺主题Token。验证：文件行数 < 500 行，无原生弹窗与非 Lucide 图标残留。
- [x] 1.2 在 `VoiceSearchOverlay` 中显式匹配中文听写（优先 `zh_CN` / `zh-CN`，无匹配时回退系统默认），并新增 `onUnavailable` 回调处理 `_speech.initialize()` 返回 `false` 或异常场景。验证：初始化失败时能立即触发 `onUnavailable` 且不抛出未捕获异常。

## 2. 长按、上滑取消手势与输入法兜底联调

- [x] 2.1 改造 `mobile/lib/widgets/home_filter_sheets.dart` 中的 `HomeSearchBar`：为搜索 `TextField` 增加可选 `focusNode` 参数；将麦克风按钮由单一 `onTap` 升级为 `onTap`（轻点提示）+ `onLongPressStart` + `onLongPressMoveUpdate`（判定 `dy < -60` 触发取消态）+ `onLongPressEnd` + `onLongPressCancel` 回调。验证：文件行数 < 500 行，手势回调签名完整。
- [x] 2.2 更新 `mobile/lib/screens/home_screen.dart`：绑定 `_searchFocusNode` 与 `GlobalKey<VoiceSearchOverlayState>`，串联轻点 Toast 提示（`CustomDialogs.showToast`）、长按呼出、上滑取消态触觉反馈（`HapticFeedback.selectionClick`）、松手触发 `finish()`/`cancel()`，以及 `onUnavailable` 时关闭浮层、聚焦搜索框拉起键盘并弹出输入法语音引导 Toast。验证：`home_screen.dart` 总行数严格 < 500 行（若超限则拆分辅助逻辑）。

## 3. 平台权限补全与静态检查

- [x] 3.1 在 `mobile/ios/Runner/Info.plist` 中补充 `NSSpeechRecognitionUsageDescription` 权限说明文案。验证：`Info.plist` XML 格式合法且包含麦克风与语音识别两项权限描述。
- [x] 3.2 在 `mobile/` 目录运行 `flutter analyze` 与 `flutter test`（如有相关测试），并检查所有修改文件的行数均 < 500 行。验证：`flutter analyze` 无新增 error，所有涉及文件行数 < 500 行。
