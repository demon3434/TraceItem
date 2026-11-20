## MODIFIED Requirements

### Requirement: Press-and-Hold Voice Search Overlay
移动端应用 SHALL 在首页搜索栏提供语音搜索入口按钮；点击后进入沉浸式语音输入模式，并在屏幕正下方提供面向老人与儿童的“按住说话、松手检索、上滑取消”大按钮交互，底层根据用户选定的语音引擎（端侧离线 `SenseVoiceSmall` / `Streaming Zipformer` 或系统原生 STT）执行识别。

#### Scenario: User presses and holds voice search button
- **WHEN** 用户点击首页搜索栏的语音按钮进入语音输入模式，并在屏幕正下方按住大麦克风按钮
- **THEN** 应用 SHALL 立即（无长按延迟）触发中等强度触觉反馈并激活波浪呼吸动效，采集 16kHz 音频并由当前选定的端侧 ASR 引擎（或系统 STT）进行中文识别；若为流式引擎则实时展示转写文本，若为整句引擎则提示“正在聆听，松开即刻识别”。

#### Scenario: User releases voice search button to trigger query
- **WHEN** 用户在未触发取消状态的情况下说完话并松开正下方按钮
- **THEN** 应用 SHALL 停止录音并完成最终解码，关闭语音输入浮层，将转写文本填入首页搜索输入框，并立即触发物品检索（联网走服务端 SQLite FTS5，离线回退本地缓存查询）。

#### Scenario: User slides finger up to cancel voice recognition
- **WHEN** 用户在按住说话过程中手指上滑超过取消阈值
- **THEN** 浮层 SHALL 切换为醒目的红色取消态视觉提示并伴随轻触觉反馈；用户松手后应用 SHALL 中止本次识别、不执行搜索，并退出录音状态回到待说话状态。

## ADDED Requirements

### Requirement: First-Run Model Selection and Download Prompt
当用户选择使用端侧离线语音模型但本地尚未下载任何模型时，应用 SHALL 在首页语音入口提供清晰的模型选择与一键下载引导，而非静默失败。

#### Scenario: 首次点击语音按钮且本地无离线模型
- **WHEN** 用户在首页点击语音搜索按钮，且当前偏好为端侧离线模型但本地尚未下载对应模型文件
- **THEN** 应用 SHALL 弹出统一样式的 `ShadSheet` 或 `ShadDialog` 引导面板，列出可从家庭服务器下载的模型（如高精度 `SenseVoiceSmall` 与轻量流式 `Streaming Zipformer`），支持一键下载后直接进入语音输入模式。

