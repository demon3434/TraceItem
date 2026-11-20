## MODIFIED Requirements

### Requirement: Press-and-Hold Voice Search Overlay
移动端应用 SHALL 在首页搜索栏提供语音搜索入口按钮；点击后进入沉浸式语音输入模式，并在屏幕正下方提供面向老人与儿童的“长按说话、松手检索、上滑取消”大按钮交互。

#### Scenario: User presses and holds voice search button
- **WHEN** 用户点击首页搜索栏的语音按钮进入语音输入模式，并在屏幕正下方长按大麦克风按钮
- **THEN** 应用 SHALL 触发中等强度触觉反馈，激活波浪呼吸动效，显式以中文（`zh_CN`）启动系统原生语音听写监听，并大字号实时展示转写文本。

#### Scenario: User releases voice search button to trigger query
- **WHEN** 用户在未触发取消状态的情况下说完话并松开正下方长按按钮
- **THEN** 应用 SHALL 停止语音监听，关闭语音输入浮层，将转写文本填入首页搜索输入框，并立即触发物品检索（联网走服务端 SQLite FTS5，离线回退本地缓存查询）。

#### Scenario: User slides finger up to cancel voice recognition
- **WHEN** 用户在长按说话过程中手指上滑超过取消阈值
- **THEN** 浮层 SHALL 切换为醒目的取消态视觉提示并伴随轻触觉反馈；用户松手后应用 SHALL 中止本次语音识别、不执行搜索，并退出录音状态回到待说话状态（用户可再次长按或点击关闭退出）。

#### Scenario: User taps voice search button to enter voice mode
- **WHEN** 用户点击首页搜索栏右侧的语音按钮
- **THEN** 应用 SHALL 弹出沉浸式语音输入浮层（此时尚未开始录音），在屏幕正下方展示大尺寸“按住说话”按钮及示例提示。

## ADDED Requirements

### Requirement: System STT Unavailable Graceful Fallback
当设备缺少可用的系统语音识别服务或麦克风/语音权限不可用时，应用 SHALL 优雅降级为输入法键盘语音兜底，避免界面卡死在录音浮层。

#### Scenario: System STT unavailable or permission denied
- **WHEN** 用户在语音输入模式长按按钮触发初始化，但端侧语音识别初始化返回不可用（如国内 Android 机型未开放 `RecognitionService` 或用户拒绝权限）
- **THEN** 应用 SHALL 自动关闭语音输入浮层，自动聚焦首页搜索框以拉起系统输入法键盘，并通过统一样式的轻量气泡提示（Toast）引导用户点击键盘上的语音输入按键完成查找。
