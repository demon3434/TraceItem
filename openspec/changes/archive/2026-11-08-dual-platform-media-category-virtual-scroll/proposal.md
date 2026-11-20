## Why

随着家庭收纳物品向数百甚至数千件扩展，当前双端应用存在显著的功能短板与性能瓶颈：
1. 物品的多媒体附件（照片、语音备忘、寻路视频）缺乏交互式查看体验，图片无法放大辨识药盒保质期或小票字迹，音视频依赖浏览器原生粗糙控件且移动端缺少预览通道；
2. 物品分类数量极少（仅 5 种），新用户注册无预设分类，且缺少完整的分类增删改与停用管理能力；
3. 标签在用户间隔离，同名标签重复创建且录入缺乏前缀智能补全提示；
4. 双端固定拉取前 100 条且 Web 端全量挂载 DOM，数据量破千时垂直滚动必出现卡顿掉帧与内存膨胀。

本次改造旨在双端（Web 与 Android）落地多媒体高精预览、建立完善的分类与共享标签体系，并引入垂直滑动窗口（Virtual Windowing）机制保障千件物品 60fps 丝滑滚动。

## What Changes

- **多模态附件高精预览与精美控件**：
  - Web 端图片预览升级为支持鼠标滚轮缩放、拖拽平移、1:1 像素复位与全屏的交互式查看器；
  - Web 端提供拟态声波、倍速切换（1.0x/1.5x）、圆角进度条的多巴胺风格胶囊音频播放组件；寻路视频提供 20px 圆角沉浸播放器，彻底移除原生播放器；
  - Android (Flutter) 端实现完整的物品详情预览层，基于 `InteractiveViewer` 支持双指缩放（1.0x~4.0x）与双击还原，并提供音视频优雅播放控件；全流程严格使用 `ShadDialog` 与 `ShadSheet`。
- **扩充预设分类与用户独立生命周期管理**：
  - 扩充系统内置分类模板至 14 套涵盖居家日常的全面分类（含 Emoji 图腾），新用户注册时自动克隆注入一套初始私有分类；
  - 增加 `is_active` 状态位，用户可自由增、删、改（名称/Emoji/排序）、停用/启用私有分类；
  - 停用分类不影响历史归档物品展示，仅在录入选择与主页快捷 Tab 隐藏；删除具有物品的分类时通过温润确认层（`ConfirmDialog` / `ShadDialog`）提供安全解绑。
- **标签跨用户复用、智能补全与幂等去重**：
  - 标签数据表调整为全局名词词库（`name` 全局唯一索引），不包含任何私有物品及位置信息；
  - 新增 `GET /api/tags/suggest?q={prefix}` 实时前缀联想接口；
  - 双端输入标签支持防抖补全下拉浮层；保存时后端执行原子查重复用主键，即使用户盲打回车也绝不产生同名冗余数据。
- **上千物品双端滑动窗口与流畅滚动**：
  - 后端支持高效分页与过滤元数据；
  - Web 端建立网格虚拟滚动窗口（Virtual Grid），仅挂载视口及前后缓冲区的卡片 DOM，外层弹性 padding 撑起真实滚动高度，将 DOM 节点数恒定在 30 个以内；
  - Android 端基于 `GridView.builder` 配合 `ScrollController` 触底无感增量翻页，严格限制列表仅加载 320px 缩略图并设定显存解码上限（`cacheWidth: 400`），彻底消除掉帧与卡顿。

## Capabilities

### New Capabilities
- `category-and-tag-system`: 涵盖 14 种居家预设分类模板库、新用户注册自动克隆、用户私有分类生命周期（增删改及停用过滤）、以及全局标签池复用、防抖前缀补全与保存幂等去重。
- `mobile-media-and-performance`: 移动端（Flutter + `shadcn_ui`）物品多模态媒体预览层（`InteractiveViewer` 捏合缩放、音视频播放）、`GridView.builder` 增量滑窗加载与缩略图显存解码优化。

### Modified Capabilities
- `web-core-experience`: 增强 Web 端媒体预览弹窗（滚轮/拖拽缩放图片、多巴胺胶囊音频条、大圆角视频播放器）以及基于虚拟视口计算的网格滑动窗口（Virtual Grid Windowing）。

## Impact

- **API 接口变更**：
  - 新增 `GET /api/tags/suggest?q={prefix}`（公共标签补全）；
  - 扩展 `GET /api/items/categories`（支持 `include_inactive=false` 过滤）；
  - 新增 `PUT /api/items/categories/{id}`、`DELETE /api/items/categories/{id}`、`PATCH /api/items/categories/{id}/status`；
  - 增强 `GET /api/items` 支持完整的标准分页参数与 total 元数据。
- **数据库 Schema 迁移**：
  - `categories` 表新增 `is_active` 字段（布尔型，默认 True）；
  - `tags` 表变更唯一约束为全局 `name` 唯一，`item_tags` 仅记录物品与全局标签映射。
- **UI 组件与规范执行**：
  - 100% 杜绝浏览器原生 `alert()` / `confirm()`，全流程采用 `ShadDialog`、`ShadSheet` 与温润自定义弹出层；
  - 严格保持每个源代码文件低于 500 行。

