# Proposal: Mobile Production Readiness (真实硬件多模态管道、老幼语音寻物与端侧生产化就绪)

## Why

图觅 (TraceItem) 移动端 (Flutter) 目前仅完成了基础的原型骨架（涵盖浏览、分页、分类管理与手势缩放），但在核心业务链路与生产运行环境中存在严重断点：
1. **多媒体采集为纯 Mock 伪代码**：登记物品时的拍照逻辑为生成虚拟色块矩阵，缺乏真实调用系统相机与相册选图的通道，且不支持音频与视频录制；
2. **多模态附件无真实播放器**：预览界面的音频和短视频仅为静态文本胶囊，用户无法点击听音或回放寻路视频；
3. **老幼语音寻物交互未落地**：缺乏端侧语音转写 (STT) 录音交互，老幼群体查找物品门槛高；
4. **系统配置与动态网络隐患**：缺少 Android 关键硬件权限与明文 HTTP 访问配置，服务器地址写死导致换网即瘫痪；缺少房屋/房间的新建与物品修改模式。

本变更旨在全面打通移动端硬件接驳与真实多模态媒体闭环，使移动端从“原型验证”跨越到“家庭真机生产可用”。

## What Changes

- **Android 系统级清单与网络自适应配置**：
  - 在 `AndroidManifest.xml` 中补齐 `INTERNET`、`usesCleartextTraffic="true"`（解决家庭内网 HTTP 访问被阻断问题）、`CAMERA`、`RECORD_AUDIO` 与多媒体存储读写权限；
  - 增加服务节点切换与局域网连接诊断设置（支持动态修改并持久化 BaseURL）。
- **真实全模态媒体采集流水线 (ADR 0003)**：
  - 引入 `image_picker`，替换现有生成伪造色彩矩阵的 Mock 代码，支持真机拍照、相册多选；
  - 接入端侧 `MediaPipeline` 进行长边 1600px 等比压缩、JPEG 82% 编码与 300px 缩略图生成；
  - 引入 `record` 库，支持 60 秒限额的 AAC/M4A 48kbps 语音备忘录录制。
- **全模态媒体播放器与回放控制**：
  - 引入 `audioplayers` 与 `video_player`，在 `MediaPreviewDialog` 中替换静态文本胶囊，实现真机音视频播放控制条（播放/暂停、进度拖拽、时长展示）。
- **老幼极简端侧语音寻物 (ADR 0004)**：
  - 引入 `speech_to_text`，在首页搜索框集成显眼的语音寻物大按钮；
  - 支持单手长按呼出多巴胺涟漪动画遮罩，松手自动将中文转写结果填入搜索框并触发毫秒级 SQLite FTS5 检索。
- **空间与物品管理能力补齐**：
  - 新增半屏温润抽屉 `SpaceManageSheet`（基于 `shadcn_ui`），支持添加/编辑房间名称与 Emoji 图腾；
  - 扩展 `ItemEditScreen`，支持已有物品的回显与更新 (Edit Mode)；
- **排版字号与美学规范治理**：
  - 全面清理移动端 `<12px` 的微小字号，严格遵守 `ui-typography-and-theming` 规范。

## Capabilities

### New Capabilities
- `mobile-voice-search`: 端侧原生中文语音听写转写与首页单手长按极简寻物交互（面向老人与儿童）。
- `mobile-space-and-item-management`: 移动端空间实体维护（房屋与房间的新增/编辑/Emoji配置）、物品编辑更新以及网络节点自适应配置。

### Modified Capabilities
- `mobile-media-and-performance`: 由原本仅定义预览交互与分页，扩展至涵盖真实硬件相机/相册采集、音频录制、端侧音视频真实回放控件与 Android 权限规范。

## Impact

- **移动端依赖 (`mobile/pubspec.yaml`)**：新增 `image_picker`, `record`, `audioplayers`, `video_player`, `speech_to_text`, `cached_network_image`。
- **Android 底层配置 (`mobile/android`)**：修改 `AndroidManifest.xml` 声明必要硬件与网络权限。
- **移动端核心页面与组件 (`mobile/lib`)**：
  - `home_screen.dart`：集成语音寻物入口、字体字号拔高；
  - `item_edit_screen.dart`：接入真实硬件采集流水线，支持新增与编辑双模式；
  - `media_preview_dialog.dart`：嵌入原生音视频播放控件；
  - `space_manage_sheet.dart`：新建空间管理半屏抽屉；
  - `api_service.dart`：支持动态更新 BaseURL 与空间/物品 PUT 更新接口。
- **后端/API**：完全复用已有 FastAPI 接口，无需破坏性变更。

