# Design: 移动端多媒体体验升级、本地LRU持久化缓存与排版重构

## Context

在家庭私有云部署场景下，移动端通过公网/外网线路（如 DDNS、内网穿透反代等，家庭宽带上行通常受限于 30Mbps 且伴随网络抖动与高延迟）访问物品多媒体附件时，存在播放重复卡顿拉流、首屏文本被大媒体挤压沉底、时限过短以及缺乏加载透明度等体验瓶颈。具体业务动因见 `proposal.md` - Why。

本设计基于现有技术栈：
- **移动端**：Flutter 3.4+，`shadcn_ui`，`video_player: ^2.9.1`，`audioplayers: ^6.0.0`，`path_provider: ^2.1.2`，`shared_preferences: ^2.2.2`；
- **单一数据源**：`shared/media_limits.json` 经 `python scripts/sync_shared.py` 自动生成 Dart 与 Python 常量；
- **服务端**：FastAPI + `FileResponse` 流式静态文件分发；
- **硬性代码规范**：单个代码文件严格 `<500 行`，严禁浏览器原生弹窗，移动端全部使用 `ShadDialog` / `ShadSheet` / `ShadToaster`。

## Goals / Non-Goals

**Goals:**
1. **本地优先与 0ms 秒开**：构建轻量级本地磁盘多媒体持久化缓存池（`MediaCacheManager`），看过的音视频与本机刚录制上传的媒体自动落盘，二次播放 0 网络流量、0 延迟秒开；
2. **Telegram 式克制存储**：默认 200MB 缓存配额，提供 100MB/200MB/500MB/1GB 用户选项与一键清理，超过配额时触发 LRU 算法自动淘汰至 80% 安全水位线；
3. **详情页文本优先排版**：重构 `ItemDetailScreen`，物品空间位置、数量、品牌、标签与长文本备注置顶展示；多媒体分解为图片（九宫格缩略图）、视频（轻量海报卡片）、音频（极简胶囊条）3 个紧凑区块；
4. **半透明元数据徽章**：图片、视频、音频统一挂载多巴胺半透明磨砂药丸徽章（`12px` 字号），清晰展示文件大小、分辨率与时长；
5. **SSOT 多档画质与数量配额升级**：在 `shared/media_limits.json` 中定义 360p/480p/720p/1080p 视频画质参数，放宽视频（60s）与音频（120s）时长，设定图片 ≤9、视频 ≤3、音频 ≤3 附件上限。

**Non-Goals:**
1. 不引入庞大重型的第三方流媒体 CDN 或复杂云端分布式转码集群（纯依托端侧与轻量私有服务器）；
2. 不构建端侧多轨视频剪辑与时间轴编辑软件（仅提供标准参数拍摄、录制与选片）；
3. 不改动现有 SQLite 实体模型结构（`Attachment` 表已有 `file_size`、`width`、`height`、`duration_seconds`，完全复用现有字段）。

## Decisions

### 1. 移动端本地磁盘缓存架构 (`MediaCacheManager`)
* **选型决策**：自主封装基于 `path_provider` 的专用轻量化 `MediaCacheManager`，而不强依赖黑盒第三方全量网络代理库。
* **文件存储路径**：存放在应用专用缓存沙箱目录：
  `<app_cache_dir>/traceitem_media_cache/{md5(file_path)}.{ext}`
* **索引与元数据**：
  在 `SharedPreferences` 中维护轻量 JSON 索引映射字典：
  ```dart
  {
    "file_path_key": {
      "local_path": "/data/user/0/.../traceitem_media_cache/abc.mp4",
      "file_size": 2451230,
      "last_accessed": 1731600000000
    }
  }
  ```
* **LRU 淘汰与安全水位线（Watermark）机制**：
  当写入新文件导致总容量超过用户设定阈值（默认 200MB）时，不是每次删除一个文件，而是将全部缓存条目按 `last_accessed` 升序排列，逐一清理本地磁盘文件与索引，直至总容量回落至阈值的 **80%（如 200MB 降至 160MB）**，大幅减少高频磁盘 I/O 抖动。

### 2. “上传即命中”端侧闭环流水线
* **决策背景**：用户在手机上录制语音或拍摄视频后，原临时文件通常被 `ImagePicker` 丢在系统临时文件夹，上传完成后如果丢弃，用户点开详情又必须通过外网重新下载，极为割裂。
* **实现策略**：
  在 `ItemEditMediaSection` 中，当 `uploadVideoFile` 或 `uploadAudioBytes` 成功取得服务端相对路径（如 `videos/2026/11/...`）后：
  1. 调用 `MediaCacheManager.instance.putFile(remoteFilePath, localSourceFile)`；
  2. 立即将原文件复制或移入缓存沙箱并建立索引；
  3. 当用户保存物品并跳转到详情页时，播放器检索 `remoteFilePath` 立即命中本地文件，实现本机 100% 零外网流量、零等待秒开。

### 3. 详情页排版彻底解耦与组件化拆分 (符合 <500 行规范)
为消除原 `ItemDetailScreen` 中巨型播放器堆叠卡屏的痛点，并严格遵守单文件 `<500 行` 红线，将详情页重构为四个精炼独立的子 Widget：
* **`ItemDetailHeaderCard`**（置顶核心文本卡片）：
  - 物品名称与编辑按钮；
  - 空间层级路径面包屑（如 `🧸 主卧 > 🛋️ 衣帽间 > 靠窗第3抽屉`）；
  - 品牌、规格、数量微徽章；
  - 分类与 Emoji 图腾；
  - 标签流动布局（`Wrap` + `ShadBadge`）；
  - 详细多行备注文本（支持长文本舒适折行，字号 14px~15px）。
* **`ItemDetailImageGrid`**（图片区块，≤9 张）：
  - 采用紧凑九宫格 / 动态网格，加载 300px 极速缩略图；
  - 缩略图右上角固定半透明磨砂药丸（展示 `1600x1200 | 420 KB`）；
  - 点击弹出 `ItemDetailGallery` 支持全屏手势缩放。
* **`ItemDetailVideoSection`**（视频区块，≤3 个）：
  - 以紧凑横向卡片排列，平时仅展示视频第一帧封面海报与播放图标徽章；
  - 浮层标注 `时长 (00:25) | 体积 (3.2 MB)`；
  - 未点击时不初始化 `VideoPlayerController`，杜绝内存与网络开销；
  - 点击后在原位平滑展开播放或弹出沉浸式大弹窗播放，自动优先读取 `MediaCacheManager` 本地文件。
* **`ItemDetailAudioSection`**（音频区块，≤3 条）：
  - 渲染为极简温润圆角条状胶囊；
  - 仅保留极速播放/暂停微按钮、时间进度（`00:15 / 00:45`）与文件大小（`320 KB`）。

### 4. 视频画质多档位体系与单一数据源 SSOT
在 `shared/media_limits.json` 中沉淀 4 档视频标准参数：
* `360p`: 640x360, 450 kbps, 24fps (极速省流，公网弱网首选)
* `480p`: 854x480, 800 kbps, 25fps (流畅标清)
* `720p`: 1280x720, 1400 kbps, 30fps (高清标准，系统默认)
* `1080p`: 1920x1080, 2800 kbps, 30fps (超清特写，精密物件与文字专用)
* **用户设置项**：在移动端 `SettingsScreen` 中提供「默认视频画质」单选，持久化于 `SharedPreferences`。录制时根据用户所选 Profile 进行参数限制。

### 5. 服务端 HTTP 响应头优化
在 `server/app/api/media.py` 的 `serve_media_file` 端点中：
* 为图片、音频、视频响应添加标准 HTTP 强缓存头：
  `Cache-Control: public, max-age=31536000, immutable`
* 结合文件的修改时间与大小生成 `ETag`，允许客户端与中间反向代理在 HTTP 层面直接命中 304 Not Modified。

### 6. Phase 2：SSOT 时长格式化与录音计时修复
* **统一格式化工具**：在 `mobile/lib/core/constants.dart`（或独立格式化工具）提供两个纯函数：
  - `formatDurationMMSS(int totalSeconds)`：将秒数格式化为 `MM:SS`（如 `5 -> 00:05`，`120 -> 02:00`），用于 `AudioRecordSheet` 的实时计时分子与上限分母。
  - `formatDurationLimitLabel(int totalSeconds)`：若 `totalSeconds >= 60 && totalSeconds % 60 == 0` 输出 `${totalSeconds ~/ 60}分钟`（如 `60 -> 1分钟`、`120 -> 2分钟`），否则输出 `${totalSeconds}秒`，用于录制按钮文案（`"1分钟短视频"`、`"2分钟录音"`）。
* **彻底消除硬编码**：`AudioRecordSheet` 的副标题、计时分母与 `ItemEditMediaSection` 的按钮文案 100% 消费 `AppConstants.audioMaxDurationSeconds` 与 `AppConstants.videoMaxDurationSeconds`。

### 7. Phase 2：编辑页与详情页「三段式」多媒体区块统一视觉规范
为消除原 `ItemEditMediaSection` 顶部计数文本拥挤、按钮大小不一及已上传视频/语音仅用简陋 `Chip` 展示的原型感，同时让编辑页与详情页保持一致的旗舰级审美，制定以下统一规范：
* **三类媒体彻底独立分区**（不再混排堆砌）：
  1. **实景照片区块**（`maxImageAttachments: 9`）：
     - 区块头：相机图标 + `"实景照片"` + 右侧圆角药丸计数徽章 `已传/上限`（如 `2/9`）。
     - 编辑页网格：3 列紧凑圆角方格（`BorderRadius.circular(14)`），已传照片展示缩略图 + 右下角半透明磨砂文件大小药丸（如 `420 KB`）+ 右上角轻量删除角标；末尾紧跟统一风格的虚线/浅底 `"添加照片"` 方格按钮（满额置灰）。**点击缩略图直接弹出 `ItemDetailGallery` 全屏缩放预览**。
     - 详情页网格：复用同一视觉语言与半透明文件大小/分辨率药丸，仅隐藏删除角标与添加方格。
  2. **寻路短视频区块**（`maxVideoAttachments: 3`）：
     - 区块头：摄像图标 + `"寻路短视频"` + 右侧圆角药丸计数徽章 `已传/上限`。
     - 已传视频列表：每条渲染为统一高度的横向精致海报卡片（左侧 `64x64` 圆角封面缩略图 + 居中播放三角徽章，中间主标题 `寻路视频 #N` 与元数据行 `时长 00:25 · 体积 3.2 MB`，编辑页右侧附带删除按钮）。**点击卡片直接弹出 `DopamineVideoPlayer` 沉浸式播放弹窗（自动命中本地缓存）**。
     - 编辑页添加按钮：全宽或等宽现代圆角按钮（高度 `48px`、`BorderRadius.circular(16)`），主文案 `"录制 ${formatDurationLimitLabel(AppConstants.videoMaxDurationSeconds)}短视频"`（如 `"录制 1分钟短视频"`），满额置灰显示 `"已达上限"`。
  3. **语音指引区块**（`maxAudioAttachments: 3`）：
     - 区块头：麦克风图标 + `"语音指引"` + 右侧圆角药丸计数徽章 `已传/上限`。
     - 已传音频列表：每条渲染为统一风格的多巴胺圆角胶囊卡片（左侧主题色圆形播放徽章，中间主标题 `语音备忘 #N` 与元数据行 `时长 00:18 · 体积 128 KB`，编辑页右侧附带删除按钮）。**点击卡片直接原地展开或弹窗调用 `DopamineAudioPlayer` 播放（自动命中本地缓存）**。
     - 编辑页添加按钮：与视频按钮等高对称的现代圆角按钮（高度 `48px`、`BorderRadius.circular(16)`），主文案 `"录制 ${formatDurationLimitLabel(AppConstants.audioMaxDurationSeconds)}录音"`（如 `"录制 2分钟录音"`），满额置灰显示 `"已达上限"`。
* **文件拆分约束 (<500 行)**：
  - 将原 469 行的 `mobile/lib/widgets/item_edit_media_section.dart` 拆分为外壳组装组件与 3 个独立子区块组件：`item_edit_image_block.dart`、`item_edit_video_block.dart`、`item_edit_audio_block.dart`（及按需抽离公共媒体预览弹窗/卡片），确保单文件严格 `<300` 行。

### 8. Phase 2：录入页表单动线、数量步进器与 Placeholder 统一规范
* **表单顺序重排**：`ItemEditScreen` 按「所属房屋/房间 -> 物品分类 -> 物品名称 -> 品牌/型号 & 数量 -> 存放具体位置 -> 特征标签 -> 备忘说明 -> 多媒体附件（照片/视频/语音三段式） -> 保存按钮」自上而下排布，优先完成核心文本录入。
* **数量步进器组件**：
  - 限制输入为纯数字（`FilteringTextInputFormatter.digitsOnly`），失焦与提交时强制兜底 `>= 1`；
  - 右侧集成 `-` / `+` 步进按钮（配 `HapticFeedback.selectionClick()`，数量为 `1` 时 `-` 按钮自动置灰禁用），并与输入区域保持充足呼吸边距，彻底解决窄屏下边框贴边/裁切问题。
* **Placeholder 全量规范为 `"如：..."`**：
  - 物品名称：`如：小林退热贴、飞利浦电风扇`
  - 品牌 / 型号：`如：小米、500ml、3号电池`
  - 存放具体位置：`如：电视柜左侧第 2 个抽屉`
  - 特征标签：`如：常用、应急、儿童（空格添加）`
  - 备忘说明：`如：2027年到期、需避光保存`

## Risks / Trade-offs

| 风险与挑战 | 对应规避策略 (Mitigation) |
| :--- | :--- |
| **[磁盘 I/O 阻塞 UI]** 大视频下载写入或 LRU 批量删除导致列表滑动掉帧 | 所有文件写入、MD5 计算与批量删除均在后台异步执行（`Future` 或 compute isolate），严禁阻塞主 Isolate。 |
| **[缓存文件损坏或被外部误删]** 用户通过第三方手机清理软件删除了沙箱文件，但 SharedPreferences 索引仍在 | 播放器检索缓存时，必须显式调用 `File(localPath).existsSync()` 校验物理文件存在性；若文件丢失，自动剔除死索引并降级回外网流式加载，杜绝黑屏崩溃。 |
| **[多视频播放状态冲突]** 详情页若有多个视频卡片，用户同时点击导致多路声音混杂 | 在 `ItemDetailScreen` 层面统一维护当前激活的播放器实例 ID，当一个卡片起播时，自动通知并暂停其他正在播放的视频或音频。 |
| **[代码行数超标]** 详情页增加多媒体区块逻辑容易突破 500 行红线 | 强制将图片网格、视频卡片列表、音频胶囊条各自抽离到独立的 Widget 文件中，Screen 仅做布局组装，每个文件控制在 150~250 行。 |

## Migration Plan

* **数据库变更**：零数据库表结构变更，完全向后兼容；
* **常量同步**：更新 `shared/media_limits.json` 后立即执行 `python scripts/sync_shared.py` 生成双端代码并运行 `--check` 确保零漂移；
* **平滑过渡**：现有已上传的历史物品在打开详情页时，将无缝应用新的置顶排版与首次播放自动落盘缓存。


### 9. Phase 3：媒体 URL 规范化、Toast 避让、卡片与空间管理重构
* **媒体路径解析与回填根治**：
  - `NetworkRouteManager.resolveMediaUrl(path)` 增加智能前缀补全：若相对路径以 `images/`、`thumbnails/`、`audios/`、`videos/` 开头（即 `/api/media/upload/*` 返回的裸相对路径），自动补齐 `/api/media/` 前缀，确保编辑态未保存时缩略图与大图预览 100% 正常加载。
  - `ItemEditScreen._initFormValues` 回填 `_attachments` 时，对 `thumbnailUrl` 剥离 `/api/media/` 前缀还原纯 `thumbnail_path`，彻底杜绝二次保存时出现 `/api/media//api/media/...` 双前缀死链。
* **全局 Toast 气泡定位与高反差配色 (`CustomDialogs.showToast`)**：
  - 底部偏移动态读取 `MediaQuery.viewPaddingOf(context).bottom + 24`，确保稳居 Android 手势条/安全区上方且水平居中；
  - 默认消息采用深炭黑底色（`Color(0xFF0F172A)`）配纯白文字（`#FFFFFF`），错误提示采用深玫瑰红（`Color(0xFFBE123C)`）配纯白文字，与明亮主题形成清晰视觉反差。
* **数量步进器与录音原地播放**：
  - `ItemEditQuantityStepper` 右侧改为上下垂直堆叠的 `ChevronUp` / `ChevronDown` 微按钮（各 20px 高）。
  - `ItemEditAudioBlock` 移除 `showDialog` 弹窗，直接渲染紧凑型 `DopamineAudioPlayer` + 拖拽手柄与删除按钮，实现原地即点即听。
* **强制首图封面与同类别拖拽重排**：
  - `ItemEditScreen._handleSave` 强制校验至少存在 1 张 `media_type == 'image'` 附件；
  - 照片、视频、语音块内数量 `>= 2` 时支持拖拽排序（`ReorderableListView` / 拖拽手柄），同步维护 `widget.attachments` 顺序及保存时的 `display_order`，第 1 张照片自动成为 `MobileItemCard` 封面图。
* **物品卡片 (`MobileItemCard`) 与详情底部栏精简**：
  - 详情页底部仅保留图标按钮（`LucideIcons.trash2` 与 `LucideIcons.pencil`），去除文字标签；
  - 物品卡片去掉品牌行，数量徽章仅展示纯数字（去掉 `x`），左下角音视频徽标去掉文字仅留圆角图标徽章，位置栏固定单行省略防折行；封面区域采用柔和浅底 + `BoxFit.contain` 完整呈现物品主体（避免不同长宽比照片被 `BoxFit.cover` 裁切关键信息）。
* **房屋与房间管理页 (`space_manage_cards.dart` / `space_manage_screen.dart`)**：
  - `SelectedHouseHeaderCard` 移除「当前房屋」标签、房间数量文本与「+ 加房间」按钮，房屋标题支持完整展示；
  - `RoomsSectionHeader` 移除「短按查看 · 长按拖拽排序」提示；
  - `RoomDragCard` 取消短按直接跳转物品列表，点击改为打开房间操作抽屉（或仅保留长按拖拽排序与 `...` 菜单）。

### 10. Phase 4：`/api/media/file/` 路径修复、画廊滑动与弹窗自动播放
* **媒体分发路径精准对齐**：
  - 服务端 `server/app/api/media.py` 路由为 `GET /api/media/file/{file_path:path}`。
  - `NetworkRouteManager.resolveMediaUrl` 对 `images/`、`thumbnails/`、`audios/`、`videos/` 裸相对路径统一补全 `/api/media/file/` 前缀（对已包含 `file/` 前缀的补全 `/api/media/`）。
  - `ItemEditScreen._initFormValues` 回填 `thumbnail_path` 时剥离 `/api/media/file/` 前缀，确保二次编辑保存后路径 100% 干净。
* **Toast 位置下移微调**：
  - `CustomDialogs.showToast` 将 `bottom` 偏移设为 `MediaQuery.viewPaddingOf(context).bottom + 20`，更加贴近屏幕底边。
* **详情页底部操作按钮尺寸与配色反转**：
  - 两个按钮统一为 `width: 56, height: 44` 等尺寸纯图标按钮；
  - 删除按钮：醒目实心玫瑰红底色（`#E11D48`）+ 白色垃圾桶图标；
  - 编辑按钮：克制浅灰白底描边（`#FFFFFF` 底 + `#CBD5E1` 边框）+ 深灰铅笔图标（`#475569`）。
* **画廊左右滑动与视频弹窗直播**：
  - `DopamineVideoPlayer` 新增 `bool autoPlay = false`，初始化完成即自动 `play()`；
  - `ItemEditVideoBlock` 与 `ItemDetailVideoSection` 点击视频卡片均弹出统一沉浸式播放弹窗并传入 `autoPlay: true`；
  - `ItemDetailGallery` 使用 `PageView.builder` 实现多图左右滑动切换，切换时重置缩放控制器并同步顶部页码与底部缩略图高亮。

### 11. Phase 5：全屏媒体预览、手势隔离、旋转纠偏与编辑卡片轻量化
* **无边距全屏图片与视频预览**：
  - 详情页与编辑页点击图片或视频卡片时，不再使用带 `EdgeInsets` 边距的居中 `Dialog`，而是统一通过全屏黑底路由（`Navigator.of(context).push(MaterialPageRoute(...))` 或无边距全屏 `Dialog.fullscreen`）铺满屏幕；
  - 屏幕右上角安全区（`SafeArea`）固定醒目的小巧红叉关闭按钮（红底白叉或高对比红叉按钮），彻底替换原弹窗关闭按钮。
* **双指缩放与左右滑切手势隔离**：
  - 在 `ItemDetailGallery` 中通过 `TransformationController` 监听缩放矩阵 `value.getMaxScaleOnAxis()`：当缩放倍率 `> 1.02` 或处于多指缩放中时，将 `PageView` 切换为 `NeverScrollableScrollPhysics()`，防止 `PageView` 横向滚动竞争吞掉 `InteractiveViewer` 的双指捏合与平移手势；
  - 确保详情页与编辑页点击任意照片时均传入完整照片列表与当前索引，支持全端左右滑切前后图片。
* **编辑页图片旋转纠偏**：
  - 为 `ItemDetailGallery` 增加可选回调 `Future<String?> Function(int index, int quarterTurns)? onRotateImage`（仅编辑页传入）；
  - 底部提供旋转按钮（每次顺时针 90° 预览，点击保存旋转或即时写回），利用 `image` 库在后台对当前图片执行旋转并重新压缩上传（生成新 `file_path` 与 `thumbnail_path` 并更新 `widget.attachments` 与本地缓存）。
* **编辑页卡片微红叉与左下角整数尺寸**：
  - 新增 `formatBytesInteger(int bytes)`（四舍五入取整，不带小数，如 `269 KB`、`17 MB`）；
  - 编辑页图片与视频缩略图左下角贴边展示无小数文件尺寸（精简字体与极小内边距，尽量不遮盖缩略图主体）；
  - 实景照片、寻路短视频、语音指引三种卡片右上角统一使用紧贴右上角的小尺寸红叉删除按钮，替代原先的垃圾桶/大删除按钮。

### 12. Phase 6：旋转直存、详情页三列视频网格与全端 0 位小数标签规范
* **旋转直存与高对比相册图标**：
  - `ItemDetailGallery` 底部旋转按钮改用相册编辑标准旋转图标（`Icons.rotate_90_degrees_cw_rounded`）与高对比深色磨砂底+主色描边/醒目底色，确保纯白图片上亦清晰可辨；
  - 点击旋转后直接调用 `onRotateSave`（每次顺时针 90°）完成旋转、上传覆盖与缓存替换，移除单独的「保存角度」确认按钮。
* **全端 0 位小数体积格式化**：
  - 将 `AppConstants.formatFileSize` 统一改为四舍五入整数格式（保留 0 位小数，如 `269 KB`、`17 MB`），消除所有小数位展示。
* **详情页图片与视频三列缩略图统一角标**：
  - `ItemDetailImageGrid` 与 `ItemDetailVideoSection` 统一复用 `MediaThumbnailSizeBadge` 在左下角贴边展示 0 位小数文件大小，与编辑页缩略图角标样式、字号完全一致；
  - `ItemDetailVideoSection` 改用 3 列网格（`crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0`）小卡片展示封面缩略图、居中播放图标与左下角体积角标。
* **全屏信息标签抽离对齐**：
  - 在 `media_section_header.dart` 抽离公共 `FullscreenInfoPill`，`ItemDetailGallery` 与 `DopamineVideoPlayer.showFullscreen` 统一在 `top: MediaQuery.viewPaddingOf(context).top + 12, left: 16` 展示，位置、尺寸、样式与字号 100% 一致；视频全屏播放器内不再重复叠加右下角/底部尺寸标签。

### 13. Phase 7：生产级多媒体全生命周期闭环与孤儿治理方案
* **1. 服务端孤儿时间保护窗口（Grace Period）**：
  - `get_all_orphan_files(db, min_age_seconds: int = 3600)` 在遍历 `images`、`audios`、`videos`、`thumbnails` 时校验 `time.time() - abs_p.stat().st_mtime >= min_age_seconds`；
  - 默认保护期 1 小时（3600 秒）：既可避免清理正在编辑上传中的文件，又确保异常断网/闪退遗留的孤儿在 1 小时后可被安全回收；`GET /api/admin/media/orphans` 与 `POST /api/admin/media/orphans/clean` 支持可选 `min_age_seconds` 查询参数（便于测试与运维应急）。
* **2. 会话级临时附件安全回收接口 (`POST /api/media/cleanup-temp`)**：
  - 请求体接收 `{ "items": [{ "file_path": "...", "thumbnail_path": "..." }] }`；
  - **双重安全校验**：
    1. 路径白名单与沙箱防穿越校验（必须位于 `settings.MEDIA_DIR` 下的 `images/`、`audios/`、`videos/`、`thumbnails/`）；
    2. **DB 零引用校验**：查询 `Attachment` 表确认 `file_path` 未被任何物品引用后，才调用 `delete_physical_attachment` 删盘，确保绝对无法借此接口误删任何已入库附件。
  - **移动端触发时机（`ItemEditScreen` + `ItemEditMediaSection`）**：
    - 维护 `_sessionUploadedFiles` 集合，记录本次打开编辑页期间上传或旋转产生的 `file_path -> thumbnail_path`；
    - 当在编辑页删除“本次刚上传”的附件、旋转替换“本次刚上传”的中间版本，或未点保存直接退出页面（`PopScope` / `dispose`）时，静默异步调用 `cleanupTempMedia`；一旦点击「保存」成功，则清空待回收标记。
* **3. 软删除物品（回收站）物理空间回收**：
  - `Admin` 侧新增统计与清理已软删除物品（`Item.is_deleted == True`）关联的物理附件与数据库记录的接口（支持按软删除留存时间或一键彻底清空），在保留防误删审计能力的同时实现存储空间闭环。
