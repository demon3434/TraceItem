## Why

Web 端在经过前期快速搭建后，与全局设计规范（ADR 0001~0010）及安全基准存在多处关键偏差与漏洞：
1. **缩略图与媒体图标失效**：因前后端字段定义不一致（`media_type` vs `file_type`），导致物品缩略图降级为纯 Emoji、音视频标记不可见；
2. **端侧媒体压缩与多模态录入残缺**：违反 ADR 0003，Web 端未在浏览器端进行 1600px JPEG 等比压缩，且缺失多图、短视频与语音备忘录关联；
3. **空间生命周期残缺**：房屋与房间仅支持创建，缺少编辑与删除（级联清理）的 UI 闭环；
4. **安全与管理阻断**：登录页明文暴露 Admin 密码（`admin123456`），TAR 备份下载因缺少 Bearer Token 导致 401 失败，上帝视角寻物无法穿透调阅附件详情；
5. **UI 排版违规**：多处违规使用小于 12px 字体（如 `text-[10px]`、`text-[11px]`），备份删除缺少二次确认。

本次变更旨在补齐 Web 端核心交互断点、落地端侧智能压缩管道、消除安全漏洞，并使全站排版严格符合无原生弹窗与多巴胺美学规范。

## What Changes

- **修复附件字段映射与图片路径**：在 `ItemCard.vue` 与各预览组件中统一采用 `media_type`，正确绑定 `/api/media/file/` 缩略图与原图访问路径。
- **集成端侧 HTML5 Canvas 智能压缩**：在 `ItemDialog.vue` 上传前，对图片自动进行长边 ≤1600px 等比缩放并以 JPEG (82% 质量) 导出后上传，避免大图消耗宽带。
- **补齐多模态附件上传与管理**：在物品登记/编辑弹窗中，支持多张实景照片、空间短视频（x265/MP4）、语音指引（AAC/M4A）的上传与列表管理；编辑模式下保留并可调整已有附件。
- **实现空间（房屋/房间）全生命周期管理**：在侧边栏空间树中提供房屋与房间的“编辑名称/图腾”与“删除空间”操作入口，弹窗调用统一 `HouseRoomDialog`（支持编辑模式）与 `ConfirmDialog`（危险删除警告）。
- **重构 TAR 备份鉴权下载与安全确认**：将 `BackupPanel.vue` 的原生直链下载重构为携带 Authorization 请求头的 Blob 文件流下载；备份删除强制接入 `ConfirmDialog`；支持自定义保留备份份数。
- **打通 Admin 上帝视角详情调阅**：在 `GodViewDialog.vue` 中支持点击检索条目调阅 `MediaPreviewDialog`，实现穿透查看归属成员、所属房屋/房间及现场照片与视频。
- **消除凭证泄露安全漏洞**：将登录页的快捷填充按钮限制在开发环境（`import.meta.env.DEV`），杜绝生产构建暴露管理员明文账号密码。
- **全面合规字号与交互弹窗**：全面清退 `text-[10px]` 和 `text-[11px]`，正文与表单标签统一规范为 14px~16px (`text-sm` ~ `text-base`)；确认零原生 `alert`/`confirm`。

## Capabilities

### New Capabilities
- `web-core-experience`: Web 端物品卡片渲染（修复 media_type 与缩略图路径）、端侧 Canvas 智能图片压缩、多模态附件（图片/视频/语音）上传与编辑管理、分页浏览支持。
- `web-space-management`: 房屋与房间的全生命周期管理（创建、修改名称与图腾、级联删除确认）。
- `web-admin-security`: 生产环境隐藏明文凭证、鉴权 Blob 流下载 TAR 备份、备份删除危险确认拦截、上帝视角穿透调阅物品媒体详情。

### Modified Capabilities
<!-- 本项目暂无现存 spec 文件，全部作为新能力在本次变更中建立基准 -->

## Impact

- **Affected Code**:
  - `web/src/components/item/ItemCard.vue`
  - `web/src/components/item/ItemDialog.vue`
  - `web/src/components/item/MediaPreviewDialog.vue`
  - `web/src/components/space/HouseRoomSidebar.vue`
  - `web/src/components/space/HouseRoomDialog.vue`
  - `web/src/components/admin/BackupPanel.vue`
  - `web/src/components/admin/GodViewDialog.vue`
  - `web/src/components/ui/ThemeSwitcher.vue`
  - `web/src/views/LoginView.vue`
  - `web/src/views/MainView.vue`
  - `web/src/api/index.ts`
  - `web/src/utils/imageCompressor.ts` (新建轻量端侧压缩工具)
- **API Impact**: 保持既有 FastAPI 接口契约不变，仅在前端补齐对现有 `PUT /houses/{id}`、`DELETE /houses/{id}`、`PUT /rooms/{id}`、`DELETE /rooms/{id}`、`/media/upload/audio`、`/media/upload/video` 的调用。
- **Dependencies**: 零新增外部重量级依赖，Canvas 压缩利用浏览器原生 API。

