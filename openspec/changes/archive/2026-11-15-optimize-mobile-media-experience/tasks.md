# Tasks

## 1. 单一数据源 (SSOT) 扩展与双端常量同步

- [x] 1.1 更新 `shared/media_limits.json`，补充附件上限（图片 ≤9、视频 ≤3、音频 ≤3）、放宽时长上限（视频 ≤60s、音频 ≤120s）、预设 4 档视频画质参数（360p、480p、720p 默认、1080p）与默认 200MB 缓存上限，校验 JSON 格式合规性
- [x] 1.2 执行 `python scripts/sync_shared.py` 重新生成 Mobile 与 Server 常量代码，运行 `python scripts/sync_shared.py --check` 验证三端零漂移

## 2. 移动端本地磁盘缓存池与上传闭环

- [x] 2.1 创建 `mobile/lib/core/media_cache_manager.dart`，实现基于 `path_provider` 的专用持久化音视频缓存池、URL 键值映射、磁盘空间统计与超过配额自动触发 LRU 淘汰至 80% 安全水位线的机制（单文件严格 <500 行）
- [x] 2.2 改造 `mobile/lib/widgets/item_edit_media_section.dart`，增加图片 9 张、视频 3 个、音频 3 条的上限边界控制与置灰逻辑；在音视频上传成功后立即就地转存至本地缓存池并绑定 URL，完成“上传即命中”端侧闭环
- [x] 2.3 改造 `mobile/lib/widgets/dopamine_video_player.dart` 与 `mobile/lib/widgets/dopamine_audio_player.dart`，加入本地缓存优先加载机制（命中即走 `File` 播放，未命中则后台流式下载并落盘）与半透明磨砂药丸徽章（展示大小与时长）

## 3. 详情页信息架构重构（文本优先 + 媒体区块化）

- [x] 3.1 创建 `mobile/lib/widgets/item_detail_header_card.dart`，实现首屏文本置顶展示：物品名称、所属房屋与房间全路径面包屑、规格、数量、分类图腾、标签 Wrap 与多行详细备注（字号 ≥14px）
- [x] 3.2 创建 `mobile/lib/widgets/item_detail_image_grid.dart`，实现图片区块九宫格/缩略图展示，右上角挂载 `尺寸 | 文件大小` 半透明磨砂药丸，点击唤起全屏大图画廊与双指捏合缩放
- [x] 3.3 创建 `mobile/lib/widgets/item_detail_video_section.dart`，实现视频区块轻量海报卡片列表，右下角标注 `时长 | 文件体积`，未点击时不初始化视频播放器，点击后平滑展开播放并自动暂停其他媒体
- [x] 3.4 创建 `mobile/lib/widgets/item_detail_audio_section.dart`，实现音频区块极简条状胶囊，展示微型播放/暂停键、时间进度与文件大小
- [x] 3.5 重构 `mobile/lib/screens/item_detail_screen.dart`，组装置顶文本卡片与三个媒体区块，彻底移除原巨型播放器堆叠卡屏逻辑，严格控制在 300 行以内

## 4. 设置项扩展、服务端 HTTP 强化与端到端验证

- [x] 4.1 在 `mobile/lib/screens/settings/settings_screen.dart` 中增加「多媒体存储与缓存」专区（实时已用体积展示、100MB/200MB/500MB/1GB 缓存配额切换、危险态 `ShadDialog` 清空缓存）以及「视频录制画质偏好」设置
- [x] 4.2 在 `server/app/api/media.py` 的 `serve_media_file` 端点中补充 `Cache-Control: public, max-age=31536000, immutable` 与 ETag 强缓存响应头，并在接口层增加附件配额校验逻辑
- [x] 4.3 运行后端单元测试 `pytest server/tests` 与前端静态代码分析 `flutter analyze mobile`，确保单文件行数 <500 行、零原生 alert/confirm、代码零语法警告并完成最终回归验证

## 5. 录入体验、三段式媒体区块重构与细节打磨 (Phase 2)

- [x] 5.1 新增 SSOT 时长格式化工具函数（`MM:SS` 实时计时格式与 `xx分钟` / `xx秒` 限长标签格式），修复 `AudioRecordSheet` 计时器分母写死 `01:00` 及分钟进位问题，确保 100% 读取 `AppConstants.audioMaxDurationSeconds`。
- [x] 5.2 重构 `ItemEditScreen` 表单顺序，将多媒体附件录入区移至页面末尾（备忘说明之后、保存按钮之上）；统一所有输入框 Placeholder 为 `"如：..."` 格式（含 `ItemEditScreen` 与 `TagAutocompleteField`）。
- [x] 5.3 在 `ItemEditScreen` 为「数量」字段实现数字输入限制（`FilteringTextInputFormatter.digitsOnly`、`>= 1` 兜底校验）与右侧 `-` / `+` 步进控制按钮，修复窄屏右侧边缘视觉裁切问题。
- [x] 5.4 拆分并重构 `ItemEditMediaSection` 为三类独立区块（`item_edit_image_block.dart`、`item_edit_video_block.dart`、`item_edit_audio_block.dart`，单文件 `<300` 行）：统一区块头与计数药丸、统一按钮尺寸与 `"xx分钟短视频"` / `"xx分钟录音"` 动态文案；为每条已上传图片、视频、音频展示缩略图/海报/胶囊与文件大小，并支持点击直接全屏预览或弹窗/原地播放。
- [x] 5.5 同步对齐详情页 `ItemDetailImageGrid`、`ItemDetailVideoSection` 与 `ItemDetailAudioSection` 的三段式区块头、计数药丸、圆角卡片与元数据展示规范，确保编辑态与预览态视觉语言 100% 一致。
- [x] 5.6 运行 `flutter analyze` 验证零静态错误，完成真机/模拟器 UI 视觉与交互核验。

## 6. 实测缺陷修复、封面强约束与卡片/空间管理重构 (Phase 3)

- [x] 6.1 优化 `CustomDialogs.showToast`：动态计入 `MediaQuery.viewPaddingOf(context).bottom` 确保气泡稳居底部安全区上方居中展示，采用深炭黑/深玫瑰红底色配纯白文字形成高反差视觉效果。
- [x] 6.2 调整 `ItemEditQuantityStepper`：将右侧横向 `-` / `+` 按钮改为最右侧上下垂直排布的微箭头按钮（`chevronUp` / `chevronDown`），提升输入区宽度与数字输入手感。
- [x] 6.3 根治图片显示与保存双前缀 Bug：在 `NetworkRouteManager.resolveMediaUrl` 智能补全 `images/`、`thumbnails/`、`audios/`、`videos/` 的 `/api/media/` 前缀；修复 `ItemEditScreen` 回填 `thumbnail_path` 时剥离 `/api/media/` 前缀，确保编辑态上传预览与保存后详情展示 100% 正常。
- [x] 6.4 实现同类别多媒体附件拖拽排序与录音原地播放：在 `ItemEditImageBlock`、`ItemEditVideoBlock`、`ItemEditAudioBlock` 中支持数量 ≥2 时拖拽调整顺序并同步更新 `display_order`；移除 `ItemEditAudioBlock` 弹窗试听，改为列表内直接播放/暂停。
- [x] 6.5 增加强制首图封面约束：`ItemEditScreen._handleSave` 校验至少包含 1 张实景照片，否则拦截提交并提示。
- [x] 6.6 精简 `ItemDetailScreen` 底部操作栏：删除与编辑按钮仅保留垃圾桶与铅笔图标，去除文字以缩小按钮占位。
- [x] 6.7 重设计 `MobileItemCard`：移除品牌展示，数量徽章去掉 `x` 前缀仅显示数字，音视频角标去掉文字仅保留图标，位置文本单行省略防折行，首图封面采用浅底自适应完整呈现（`BoxFit.contain`）避免裁切物品主体。
- [x] 6.8 优化「房屋与房间」管理页（`space_manage_cards.dart` 与 `space_manage_screen.dart`）：移除房屋卡片的「当前房屋」标签、房间数量文案与「+ 加房间」按钮以完整展现房屋名；移除「短按查看 · 长按拖拽排序」文本；取消短按房间直接跳转物品列表的行为。
- [x] 6.9 运行 `flutter analyze` 验证零警告，并重新构建 ARMv8 Release APK。

## 6. 实测缺陷修复、封面强约束与卡片/空间管理重构 (Phase 3)

- [x] 6.1 优化 `CustomDialogs.showToast`：动态计入 `MediaQuery.viewPaddingOf(context).bottom` 确保气泡稳居底部安全区上方居中展示，采用深炭黑/深玫瑰红底色配纯白文字形成高反差视觉效果。
- [x] 6.2 调整 `ItemEditQuantityStepper`：将右侧横向 `-` / `+` 按钮改为最右侧上下垂直排布的微箭头按钮（`chevronUp` / `chevronDown`），提升输入区宽度与数字输入手感。
- [x] 6.3 根治图片显示与保存双前缀 Bug：在 `NetworkRouteManager.resolveMediaUrl` 智能补全 `images/`、`thumbnails/`、`audios/`、`videos/` 的 `/api/media/` 前缀；修复 `ItemEditScreen` 回填 `thumbnail_path` 时剥离 `/api/media/` 前缀，确保编辑态上传预览与保存后详情展示 100% 正常。
- [x] 6.4 实现同类别多媒体附件拖拽排序与录音原地播放：在 `ItemEditImageBlock`、`ItemEditVideoBlock`、`ItemEditAudioBlock` 中支持数量 ≥2 时拖拽调整顺序并同步更新 `display_order`；移除 `ItemEditAudioBlock` 弹窗试听，改为列表内直接播放/暂停。
- [x] 6.5 增加强制首图封面约束：`ItemEditScreen._handleSave` 校验至少包含 1 张实景照片，否则拦截提交并提示。
- [x] 6.6 精简 `ItemDetailScreen` 底部操作栏：删除与编辑按钮仅保留垃圾桶与铅笔图标，去除文字以缩小按钮占位。
- [x] 6.7 重设计 `MobileItemCard`：移除品牌展示，数量徽章去掉 `x` 前缀仅显示数字，音视频角标去掉文字仅保留图标，位置文本单行省略防折行，首图封面采用浅底自适应完整呈现（`BoxFit.contain`）避免裁切物品主体。
- [x] 6.8 优化「房屋与房间」管理页（`space_manage_cards.dart` 与 `space_manage_screen.dart`）：移除房屋卡片的「当前房屋」标签、房间数量文案与「+ 加房间」按钮以完整展现房屋名；移除「短按查看 · 长按拖拽排序」文本；取消短按房间直接跳转物品列表的行为。
- [x] 6.9 运行 `flutter analyze` 验证零警告，并重新构建 ARMv8 Release APK。

## 7. 路径前缀根治、弹窗直播、画廊左右滑与细节微调 (Phase 4)

- [x] 7.1 修复 `NetworkRouteManager.resolveMediaUrl` 补全 `/api/media/file/` 前缀（而非 `/api/media/`），并修复 `ItemEditScreen` 回填 `thumbnail_path` 时剥离 `/api/media/file/` 前缀，彻底解决上传及保存后图片无法显示的问题。
- [x] 7.2 微调 `CustomDialogs.showToast` 底部偏移至 `MediaQuery.viewPaddingOf(context).bottom + 20`，使其更贴近屏幕下边缘。
- [x] 7.3 调整 `ItemDetailScreen` 底部删除与编辑按钮：两者保持完全一致的尺寸（`56x44`），删除按钮改为醒目红底白图标，编辑铅笔按钮改为低调浅色描边配色。
- [x] 7.4 为 `DopamineVideoPlayer` 新增 `autoPlay` 参数，并在 `ItemEditVideoBlock` 与 `ItemDetailVideoSection` 点击视频卡片时弹出沉浸式播放层直接自动播放（详情页默认仅展示缩略图海报）。
- [x] 7.5 升级 `ItemDetailGallery` 支持 `PageView.builder` 左右滑动切换多张图片，并保留双指缩放与底部缩略图联动。
- [x] 7.6 运行 `flutter analyze` 验证零警告，并重新构建 ARMv8 Release APK。

## 8. 全屏预览、双指缩放修复、图片旋转与编辑卡片轻量化 (Phase 5)

- [x] 8.1 新增/重构全屏沉浸式图片与视频预览路由（`ItemDetailGallery` 全屏化 + 视频全屏播放器），屏幕右上角安全区固定小巧醒目的红叉关闭按钮，替换详情页与编辑页的局部弹出层预览。
- [x] 8.2 修复 `ItemDetailGallery` 中 `InteractiveViewer` 与 `PageView` 手势竞争导致的双指无法缩放 Bug（缩放倍率 >1.02 时锁定翻页并确保双指捏合灵敏），并确保编辑页点击图片也传入完整图片列表以支持左右滑切前后图片。
- [x] 8.3 为全屏图片预览增加编辑页旋转按钮（顺时针 90° 旋转图片像素、重新生成缩略图并上传替换对应附件及缓存）。
- [x] 8.4 新增无小数整数文件体积格式化工具（如 `269 KB`、`17 MB`），并将编辑页图片与视频缩略图的尺寸角标调整至左下角贴边展示、尽量减少遮挡。
- [x] 8.5 将编辑页实景照片、寻路短视频、语音指引三类附件卡片的删除按钮统一改为右上角贴边微缩红叉按钮。
- [x] 8.6 运行 `flutter analyze` 验证零警告，并构建 ARMv8 Release APK。

## 9. 旋转直存、详情页三列视频网格与全端 0 位小数对齐 (Phase 6)

- [x] 9.1 将 `AppConstants.formatFileSize` 统一改为保留 0 位小数整数格式（所有文件大小标签均不显示小数）。
- [x] 9.2 抽离公共 `FullscreenInfoPill` 组件并应用到 `ItemDetailGallery` 与 `DopamineVideoPlayer.showFullscreen`，确保视频全屏预览文件大小标签的位置、尺寸、样式、字号与图片全屏完全一致。
- [x] 9.3 升级 `ItemDetailGallery` 旋转按钮为手机相册旋转图标 + 高对比醒目配色（白图可见），点击后直接旋转保存覆盖原图与缓存，移除二次「保存角度」按钮。
- [x] 9.4 统一 `ItemDetailImageGrid`（单图与多图）缩略图左下角贴边展示 `MediaThumbnailSizeBadge`（0 位小数，与编辑页缩略图角标样式及字号完全一致）。
- [x] 9.5 重构 `ItemDetailVideoSection` 为一行 3 个小卡片网格（`crossAxisCount: 3`），展示封面缩略图、居中播放图标与左下角贴边 0 位小数文件大小，点击全屏播放。
- [x] 9.6 运行 `flutter analyze` 验证零警告，并构建 ARMv8 Release APK。

## 10. 生产级多媒体孤儿治理与全生命周期闭环 (Phase 7)

- [x] 10.1 服务端 `server/app/services/admin_service.py` 为 `get_all_orphan_files` / `scan_orphan_media` / `clean_orphan_media` 增加 `min_age_seconds`（默认 3600s）时间保护窗口，并在 `server/app/api/admin.py` 暴露可选参数，防止误删正在编辑上传的文件。
- [x] 10.2 服务端在 `server/app/api/media.py` 新增 `POST /api/media/cleanup-temp` 接口，严格校验路径沙箱与 `Attachment` 表零引用后物理删除未入库临时附件及缩略图。
- [x] 10.3 移动端 `ItemEditScreen`、`ItemEditMediaSection` 与 `ApiService` 追踪本轮会话新上传/旋转产生的未入库附件，在移除未保存附件、连续旋转替换或取消退出编辑时静默调用 `cleanup-temp` 即时回收。
- [x] 10.4 服务端 `admin_service.py` 与 `admin.py` 新增已软删除物品媒体统计与彻底清理接口，补齐回收站物理空间释放闭环。
- [x] 10.5 补充服务端孤儿保护期、`cleanup-temp` 防误删校验及软删除彻底清理自动化测试，运行 `pytest server/tests` 与 `flutter analyze` 验证通过。
- [x] 10.6 部署最新服务端至 `192.168.7.186` 并重新构建 ARMv8 Release APK。
