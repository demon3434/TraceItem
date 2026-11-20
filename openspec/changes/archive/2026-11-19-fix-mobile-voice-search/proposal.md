## Why

当前移动端语音寻物功能仅完成了底层依赖引入与全屏浮层 UI 骨架（`VoiceSearchOverlay`），交互闭环处于断开状态：`HomeSearchBar` 麦克风按钮仅响应 `onTap`，浮层内的 `finish()` 与 `cancel()` 从未被触发，导致点击后无法完成检索也无法关闭。同时，国内 Android 机型（如荣耀 MagicOS 等未预置 Google 语音服务的 ROM）可能不存在可用的系统 `RecognitionService`，当前缺少不可用检测与降级兜底方案。

## What Changes

- 将 `HomeSearchBar` 麦克风按钮改造为**长按说话 + 上滑取消 + 轻点提示**交互：
  - 长按触发触觉反馈并弹出 `VoiceSearchOverlay`，显式使用 `zh_CN` 激活端侧语音听写；
  - 上滑超过阈值切换为取消态视觉与触觉反馈，松手调用 `cancel()` 放弃检索并关闭浮层；
  - 正常松手调用 `finish()`，将转写文本填入搜索框并立即触发检索；
  - 轻点（非长按）时通过 `CustomDialogs.showToast` 给出“按住说话，松开立即查找”轻量提示。
- 新增**国内 Android 系统 STT 不可用兜底（方案 C）**：当 `SpeechToText.initialize()` 返回不可用或权限受限时，自动关闭语音浮层、聚焦首页搜索框以拉起系统输入法键盘，并通过 `CustomDialogs.showToast` 引导用户点击键盘内置语音按键输入。
- 在 `VoiceSearchOverlay` 中采用 Lucide Icons 替换残留 Material 图标，遵循当前主题色板与多巴胺视觉规范；在 `ios/Runner/Info.plist` 补充 `NSSpeechRecognitionUsageDescription`。
- 全程使用自定义浮层 `VoiceSearchOverlay` 与统一样式气泡 `CustomDialogs.showToast`（内部基于 `ShadToaster`），严禁任何原生 `alert` / `confirm` / 系统裸弹窗。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mobile-voice-search`: 完善长按语音识别与上滑取消手势闭环、轻点操作提示，并新增系统语音引擎不可用时自动聚焦搜索框弹出键盘与 Toast 引导的降级兜底需求。

## Impact

- 移动端代码：
  - `mobile/lib/widgets/home_filter_sheets.dart`（`HomeSearchBar` 手势与 `FocusNode` 支持）
  - `mobile/lib/widgets/voice_search_overlay.dart`（取消态视觉、状态控制、`zh_CN` 指定、不可用回调、Lucide Icons 统一）
  - `mobile/lib/screens/home_screen.dart`（长按/拖动/松手状态联动、搜索框 `FocusNode` 聚焦兜底，注意保持单文件 < 500 行）
  - `mobile/ios/Runner/Info.plist`（补充语音识别权限描述）
- 规范文档：`openspec/specs/mobile-voice-search/spec.md`

