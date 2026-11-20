## MODIFIED Requirements

### Requirement: Press-and-Hold Voice Search Overlay
移动端应用 SHALL 在首页搜索栏提供语音搜索入口按钮；点击后进入沉浸式语音输入模式（顶部仅保留关闭按钮，不显示底层引擎名称标签），在屏幕正下方提供“按住说话、松手分词选词、上滑取消”交互，用户点选确认候选词后再填入搜索框触发检索。

#### Scenario: User presses and holds voice search button
- **WHEN** 用户点击首页搜索栏的语音按钮进入语音输入模式，并在屏幕正下方按住大麦克风按钮
- **THEN** 应用 SHALL 立即触发中等强度触觉反馈并激活波浪呼吸动效，采集 16kHz 音频并由当前选定的端侧 ASR 引擎（或系统 STT）进行中文识别；顶部不展示“引擎: xxx”标签。

#### Scenario: User releases voice search button to trigger query
- **WHEN** 用户在未触发取消状态的情况下说完话并松开正下方按钮
- **THEN** 应用 SHALL 停止录音并完成解码，原中部提示框内容消失并在原地切换为分词候选词选择面板（展示去标点后的识别原句、可多选大号候选词胶囊、可微调预览输入框及「重新说话」「确认并搜索」按钮）；用户点击「确认并搜索」后，应用 SHALL 将确认的关键词填入首页搜索输入框，关闭浮层并立即触发检索。

#### Scenario: User slides finger up to cancel voice recognition
- **WHEN** 用户在按住说话过程中手指上滑超过取消阈值
- **THEN** 浮层 SHALL 切换为醒目的红色取消态视觉提示并伴随轻触觉反馈；用户松手后应用 SHALL 中止本次识别、不执行搜索，并退出录音状态回到待说话状态。

