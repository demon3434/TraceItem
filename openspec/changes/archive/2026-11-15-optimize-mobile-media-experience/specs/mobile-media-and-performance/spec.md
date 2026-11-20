# Spec Delta: mobile-media-and-performance

## MODIFIED Requirements

### Requirement: Interactive Mobile Media Preview Layer
移动端 SHALL 在 `ItemDetailScreen` 采用「文本优先置顶 + 媒体紧凑区块化」的信息架构，确保空间位置全路径、数量、规格、标签与长文本备注置于首屏最上方；多媒体附件统一按图片、视频、音频分区块紧凑呈现，未点击时不渲染重型播放器，并统一搭载半透明磨砂文件大小药丸徽章。

#### Scenario: User pinches to zoom photo
- **WHEN** 用户点击物品卡片进入全屏 `ItemDetailScreen` 查看照片
- **THEN** 应用 SHALL 支持多张照片（最多 9 张）紧凑九宫格展示，右上角展示半透明尺寸药丸徽章，并允许点击进入画廊在 1.0x 至 4.0x 倍率间双指捏合缩放、双击在 1.0x 与 2.5x 间切换及拖拽平移细节。

#### Scenario: User plays audio guide or video guide
- **WHEN** 物品包含语音备忘（最多 3 条）或寻路短视频（最多 3 个）附件
- **THEN** `ItemDetailScreen` SHALL 以海报卡片与极简胶囊条形式展示，标注时长与文件大小，未点击时不渲染重型播放器，点击后支持播放、暂停、进度条拖拽并优先读取本地磁盘缓存。

#### Scenario: 文本属性与详细备注置顶清晰展现
- **WHEN** 用户点击物品卡片进入 `ItemDetailScreen`
- **THEN** 页面首屏最上方 SHALL 首先展示物品名称、所属房屋与房间层级路径、品牌规格、数量、所属分类、标签与详细备注文本，用户无需滚屏即可一眼掌握全部核心文本信息。

#### Scenario: 在详情页直接执行编辑与危险删除
- **WHEN** 用户在 `ItemDetailScreen` 浏览物品详情
- **THEN** 页面底部常驻操作栏 SHALL 提供「编辑信息」（跳转至 `ItemEditScreen`）与「删除物品」（弹出危险态 `ShadDialog` 二次确认后调用 `DELETE /api/items/{id}`）。

### Requirement: Real Hardware Multimodal Capture and Compression Pipeline
The mobile application SHALL provide direct acquisition channels from physical device cameras, system photo galleries, and microphones, executing client-side compression before uploading to the server, and honoring user-configured video profiles and extended duration limits.

#### Scenario: User captures physical item photo via camera or album
- **WHEN** a user selects "Take Photo" or "Choose from Album" in the item editing interface
- **THEN** the mobile app SHALL invoke the system camera or gallery picker, correct EXIF rotation, downscale the image to long edge <= 1600px, compress to JPEG at 82% quality, generate a 300px thumbnail, and upload both to `/api/media/upload/image`.

#### Scenario: User records voice memo guide
- **WHEN** a user taps and records a voice memo guide for an item
- **THEN** the mobile app SHALL record up to `AppConstants.audioMaxDurationSeconds` (120s) of AAC/M4A audio at 48kbps, display real-time elapsed recording time and dynamic max duration formatted as `MM:SS / MM:SS` (e.g. `00:05 / 02:00` rather than hardcoded `01:00`), and allow previewing before submission.

#### Scenario: 录制或导入寻路短视频并执行用户画质配置
- **WHEN** 用户在 `ItemEditScreen` 录制或导入寻路短视频
- **THEN** 移动端 SHALL 支持最长 60 秒录制，并按照用户在通用设置中选定的画质档位（360p、480p、720p 默认、1080p）参数进行尺寸与码率规范化，完成 FastStart MOOV 头部前置与关键帧锁定后上传。

### Requirement: 全模态物品创建与编辑能力对齐
移动端物品录入与编辑页 `ItemEditScreen` SHALL 补齐与 Web 端普通成员一致的全量表单字段与媒体能力，严格执行 `>= 12px` 字号、`ShadToaster` 反馈规范及附件数量硬性配额（图片 ≤9、视频 ≤3、音频 ≤3）。

#### Scenario: 录入或修改分类、多图、短视频、语音与联想标签
- **WHEN** 用户在 `ItemEditScreen` 新增或编辑物品
- **THEN** 用户 SHALL 可选择所属房屋与房间（支持继承空间锚定）、选择启用中的物品分类、上传或移除最多 9 张端侧压缩图片、拍摄或选取最多 3 个最长 60 秒的现场短视频、录制最多 3 条最长 120 秒语音备忘录，并在输入标签时通过 `GET /api/items/tags/suggest` 获取前缀联想建议。

#### Scenario: 附件达到上限时友好置灰拦截
- **WHEN** 某类媒体附件已达配额上限（如图片已满 9 张、视频已满 3 个、音频已满 3 条）
- **THEN** 对应的添加按钮 SHALL 自动置灰并展示 `已达上限` 状态，点击时弹出温润提示 Toast，防止超额录入。

## ADDED Requirements

### Requirement: Mobile Media Persistent Disk Cache and LRU Eviction
移动端 SHALL 维护具备固定配额（默认 200MB，支持用户在设置中自定义）的本地磁盘多媒体持久化缓存池，对音视频媒体实施「本地优先播放」、「上传即命中」及「LRU 自动淘汰」策略，彻底解决公网高延迟卡顿并严格保护手机存储空间。

#### Scenario: 本地缓存命中实现零秒开播放
- **WHEN** 用户在 `ItemDetailScreen` 点击播放视频或音频，且该文件在本地缓存池中已存在
- **THEN** 播放器 SHALL 直接加载本地沙箱文件路径（`VideoPlayerController.file` / `DeviceFileSource`），实现 0ms 本地秒开，零外网流量消耗。

#### Scenario: 本地未命中时流式下载并异步落盘
- **WHEN** 用户播放未缓存的远程媒体文件
- **THEN** 播放器 SHALL 从外网服务器流式加载，并在后台将媒体完整持久化至本地缓存池，自动与服务端文件路径建立索引映射，确保二次打开时直接命中本地缓存。

#### Scenario: 本机刚上传的音视频就地转存为本地缓存
- **WHEN** 用户在本机 `ItemEditScreen` 录制或拍摄音视频并成功上传服务端
- **THEN** 移动端客户端 SHALL 立即将该本地原文件转存至缓存池目录并关联服务端返回的 `file_path`，确保该用户在当前设备查看该物品时 100% 命中本地缓存，无需二次通过外网回下。

#### Scenario: 缓存超出配额触发 LRU 自动清理至安全水位
- **WHEN** 写入新媒体导致缓存总容量超过用户设定的配额上限（默认 200MB）
- **THEN** 缓存管理器 SHALL 按各缓存文件的最后访问时间（`last_accessed_time`）正序排列，自动剔除最久未访问的媒体文件，直至总容量降至配额的 80% 安全水位线以内。

#### Scenario: 通用设置中管理缓存配额与一键清理
- **WHEN** 用户进入「通用设置」的「多媒体存储与缓存」专区
- **THEN** 页面 SHALL 实时展示当前已用缓存体积与配额比例，支持在 100MB、200MB、500MB 与 1GB 之间切换配额上限，并提供「立即清空缓存」操作（弹出危险态 `ShadDialog` 二次确认后安全清除本地缓存目录并重置索引）。

### Requirement: 三段式独立媒体区块与双端统一视觉规范
移动端物品编辑页（`ItemEditMediaSection`）与详情页（`ItemDetailScreen`）SHALL 将「实景照片」「寻路短视频」「语音指引」彻底拆分为 3 个独立且视觉语言统一的区块，每条附件均需展示文件大小并支持点击直接预览或播放，录制按钮文案 SHALL 动态读取 `shared/media_limits.json` 配置。

#### Scenario: 独立区块头、计数药丸与动态时长按钮文案
- **WHEN** 用户在 `ItemEditScreen` 或 `ItemDetailScreen` 查看多媒体区域
- **THEN** 照片、视频、音频 SHALL 各自拥有独立的区块头（图标 + 标题 + 右侧圆角计数药丸如 `0/9`、`0/3`），编辑页视频与音频添加按钮 SHALL 等高对齐并分别显示 `"xx分钟短视频"` 与 `"xx分钟录音"`（时长从 `AppConstants.videoMaxDurationSeconds` / `AppConstants.audioMaxDurationSeconds` 动态格式化）。

#### Scenario: 上传后附件展示缩略图/卡片与文件大小并支持点击预览播放
- **WHEN** 用户在 `ItemEditScreen` 上传照片、短视频或录音后
- **THEN** 每条照片 SHALL 以圆角缩略图展示文件大小且点击可弹出 `ItemDetailGallery` 全屏缩放预览；每条短视频 SHALL 以横向海报卡片展示封面缩略图、时长与文件大小且点击可弹出 `DopamineVideoPlayer` 播放；每条语音 SHALL 以圆角胶囊卡片展示时长与文件大小且点击可播放试听。

### Requirement: 录入页文本优先动线、数量步进器与 Placeholder 规范
`ItemEditScreen` SHALL 采用「文本属性在前、多媒体附件在末尾」的录入顺序，提供防错数量步进器，并统一所有文本输入框的提示文案格式。

#### Scenario: 多媒体区置于末尾且输入框统一使用「如：」提示
- **WHEN** 用户打开 `ItemEditScreen` 新增或编辑物品
- **THEN** 多媒体附件录入区 SHALL 位于备忘说明之后、保存按钮之上；所有文本输入框的 `placeholder`（包括物品名称、品牌/型号、存放具体位置、特征标签、备忘说明）SHALL 统一以 `"如："` 开头并给出具体示例。

#### Scenario: 数量输入框限制正整数并提供加减步进按钮
- **WHEN** 用户编辑物品数量字段
- **THEN** 输入框 SHALL 仅允许输入数字并确保值严格大于 0（`>= 1`），且右侧 SHALL 提供 `-` 与 `+` 步进辅助按钮（数量为 1 时 `-` 按钮禁用）并避免窄屏边框裁切。

### Requirement: 媒体路径统一解析、强制封面图片与同类别拖拽排序
移动端 SHALL 正确解析上传接口返回的相对路径与详情接口返回的 `/api/media/...` 路径，强制物品至少保留 1 张实景照片作为封面，并支持编辑页同类别多附件拖拽排序。

#### Scenario: 未保存与已保存的图片均可正常显示缩略图与全屏预览
- **WHEN** 用户在 `ItemEditScreen` 新上传图片（尚未提交保存）或编辑已有物品的图片
- **THEN** 缩略图与点击全屏预览（`ItemDetailGallery`）SHALL 均能正确拼接 `/api/media/` 路径正常显示，且二次保存后不会出现双前缀死链。

#### Scenario: 强制至少保留 1 张实景照片与同类别拖拽调整顺序
- **WHEN** 用户在 `ItemEditScreen` 保存物品或对同一类别的多个附件（≥2 个）拖拽排序
- **THEN** 若图片数量为 0，系统 SHALL 拦截保存并弹出高反差 Toast 提示至少保留 1 张图片；拖拽调整顺序后 SHALL 同步更新 `display_order`，且第 1 张图片自动作为物品卡片封面图。

### Requirement: 物品卡片、详情底栏、空间管理页与全局 Toast 美学精简规范
移动端 SHALL 统一优化全局 Toast 避让与反差配色、`MobileItemCard` 信息密度与封面自适应展示、详情页纯图标底栏，以及房屋/房间管理页的无噪点布局。

#### Scenario: 居中高反差 Toast 避让底部手势导航栏
- **WHEN** 客户端触发 `CustomDialogs.showToast`
- **THEN** 气泡 SHALL 水平居中悬浮于底部安全区上方（避让系统手势横条），采用深色底色配浅色文字以与明亮主界面形成清晰反差。

#### Scenario: 物品卡片去噪与封面完整自适应呈现
- **WHEN** 首页或空间页渲染 `MobileItemCard`
- **THEN** 卡片 SHALL 隐藏品牌文本、隐藏数量 `x` 前缀（仅显示数字）、音视频角标仅显示图标不显示文字、长位置文本单行省略不折行，并以第 1 张实景照片作为封面且通过自适应缩放完整展示物品主体避免裁切。

#### Scenario: 房屋卡片完整显示名称且点击房间不误跳转
- **WHEN** 用户浏览「房屋与房间」管理页面
- **THEN** 房屋摘要卡片 SHALL 移除「当前房屋」标签、房间数统计与「+ 加房间」按钮以完整展示房屋名称，引导条移除「短按查看 · 长按拖拽排序」提示，且短按房间卡片不再直接跳转查看物品页面。

### Requirement: 媒体分发路径 `/api/media/file/` 对齐与画廊/视频弹窗直播交互
移动端 SHALL 正确拼接 `/api/media/file/` 前缀加载所有图片与音视频，并在详情页与编辑页提供左右滑动切换大图及点击视频直接自动播放体验。

#### Scenario: 正确拼接 `/api/media/file/` 展示上传与保存后的图片
- **WHEN** 用户上传图片或编辑保存物品后查看缩略图与详情大图
- **THEN** `resolveMediaUrl` SHALL 为相对路径自动补全 `/api/media/file/` 前缀，编辑回填 SHALL 剥离 `/api/media/file/`，确保图片 100% 加载成功。

#### Scenario: 多图画廊支持左右滑动切换与视频点击弹窗直接自动播放
- **WHEN** 用户在详情页点击图片或视频缩略图卡片
- **THEN** 多图预览弹窗 SHALL 支持左右滑动切换前后图片并支持双指缩放；视频点击后 SHALL 在弹出层中直接自动播放，无需二次点击播放键。

#### Scenario: 详情页底栏等宽按钮与 Toast 下移微调
- **WHEN** 用户查看物品详情页底部操作栏或触发 Toast 提示
- **THEN** 删除按钮 SHALL 为醒目红底白图标、编辑按钮为低调描边配色且两者尺寸完全一致；Toast SHALL 悬浮于 `viewPadding.bottom + 20` 贴近屏幕下边缘。

### Requirement: 全屏图片/视频预览、手势缩放隔离、旋转纠偏与编辑卡片轻量化
移动端 SHALL 为详情页与编辑页提供全屏沉浸式图片/视频预览（右上角红叉关闭）、无冲突的双指缩放与左右滑切、编辑页图片旋转调整，以及不遮挡缩略图的微红叉删除与左下角整数体积角标。

#### Scenario: 全屏放大预览与右上角红叉关闭
- **WHEN** 用户在物品详情页或编辑页点击图片或视频缩略图卡片
- **THEN** 客户端 SHALL 打开真正全屏的黑底沉浸式预览页面（而非局部弹出层），并在屏幕右上角安全区内固定醒目的红叉关闭按钮。

#### Scenario: 双指捏合缩放与左右滑动切换互不干扰
- **WHEN** 用户在全屏图片画廊中双指捏合缩放或左右滑动切换图片
- **THEN** 图片 SHALL 灵敏响应 1.0x 至 4.0x 双指捏合缩放（缩放放大后自动锁定翻页手势避免冲突），且在 1.0x 原始比例下可流畅左右滑动切换同一物品的前后图片（详情页与编辑页一致）。

#### Scenario: 编辑页全屏预览支持旋转调整图片角度
- **WHEN** 用户在编辑页点击放大图片并点击旋转按钮
- **THEN** 客户端 SHALL 支持顺时针 90° 旋转预览并保存旋转后的图片（重新压缩上传并同步更新该附件条目与本地缓存）。

#### Scenario: 编辑页卡片右上角微红叉与左下角整数体积展示
- **WHEN** 用户在编辑页查看已上传的图片、视频或语音卡片
- **THEN** 三类卡片右上角 SHALL 统一使用紧贴角落的小尺寸红叉删除按钮（减少对缩略图的遮挡）；图片与视频缩略图左下角 SHALL 贴着边框展示无小数文件尺寸（如 `269 KB`、`17 MB`）。

#### Scenario: 编辑页点击相册旋转图标直接保存覆盖
- **WHEN** 用户在编辑页全屏预览图片并点击高对比度相册旋转按钮
- **THEN** 客户端 SHALL 直接顺时针旋转 90° 并保存覆盖当前附件与缓存，无需额外点击二次确认按钮，且在白色图片背景下按钮依然醒目可见。

#### Scenario: 详情页视频三列小卡片与全端 0 位小数体积对齐
- **WHEN** 用户在物品详情页浏览照片与视频，或进入视频全屏预览
- **THEN** 详情页图片与视频缩略图 SHALL 统一在左下角贴边展示 0 位小数文件大小（与编辑页角标样式、字号一致），视频区块 SHALL 采用一行 3 个小卡片网格；全端所有文件大小标签均保留 0 位小数，且视频全屏预览与图片全屏预览的顶栏信息标签位置、尺寸、样式、字号完全一致。

### Requirement: 生产级多媒体孤儿文件防误删与全生命周期闭环治理
系统 SHALL 在保留「先上传、后提交」预上传优势的同时，通过时间保护窗口、编辑会话即时回收及软删除物理清理机制，防止服务端磁盘产生永久孤儿文件或误删正在编辑中的附件。

#### Scenario: 孤儿扫描与清理遵守时间保护窗口防止误删在编文件
- **WHEN** 管理员调用 `GET /api/admin/media/orphans` 或 `POST /api/admin/media/orphans/clean`
- **THEN** 系统 SHALL 仅将未被 `Attachment` 表引用且修改时间超过保护期（默认 `3600` 秒）的文件计入或清理，1 小时内刚上传的临时文件 SHALL 受到保护不被误删。

#### Scenario: 客户端放弃编辑、移除未保存附件或连续旋转时即时回收临时文件
- **WHEN** 用户在新增/编辑页面上传或旋转图片后未点击保存即退出、在保存前移除本轮新上传的附件，或连续多次旋转替换中间版本
- **THEN** 客户端 SHALL 异步调用 `POST /api/media/cleanup-temp` 清理本轮未入库的临时文件；服务端 SHALL 在校验路径沙箱与数据库零引用后物理删盘。

#### Scenario: 管理员可审计并彻底清理已软删除物品占用的媒体空间
- **WHEN** 管理员在后台执行存储治理
- **THEN** 系统 SHALL 支持统计并按需彻底清理已标记 `is_deleted = True` 的物品记录及其关联物理附件与缩略图，释放长期占用的磁盘空间。
