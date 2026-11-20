## Context

当前 Web 端基于 Vue 3 + Tailwind CSS 构建，整体设计理念遵循 Monorepo 统一架构（ADR 0002）与无原生弹窗的多巴胺儿童友好 UI 规范（ADR 0010）。
在实现细节上，Web 端与后端 FastAPI 接口及媒体工业化存储约定产生了几处实现脱节（如 `media_type` 字段拼写为 `file_type`、未提供空间改删入口、备份直链缺少 Auth Token）。同时，为了符合 `AGENTS.md` 单文件小于 500 行的红线要求，所有功能升级必须采取高内聚低耦合的组件抽离方式。

## Goals / Non-Goals

**Goals:**
- **完全修复媒体渲染通路**：在不破坏现有类型定义的前提下，准确映射 `media_type`，使卡片缩略图、现场大图及音视频角标 100% 正确展示。
- **端侧智能压缩轻量化落地**：抽取独立工具函数 `web/src/utils/imageCompressor.ts`，在浏览器使用原生 `HTMLCanvasElement` 毫秒级压缩照片，无需引入笨重 WASM 依赖。
- **空间全生命周期闭环**：使 `HouseRoomSidebar.vue` 与 `HouseRoomDialog.vue` 支持对已有房屋与房间的重命名、图腾修改和删除，危险删除由 `ConfirmDialog.vue` 拦截。
- **安全与管理链路加固**：
  - 生产构建彻底隐藏默认测试密码；
  - 备份下载封装为带 Bearer Token 的 Axios Blob 下载；
  - 备份删除增加 `ConfirmDialog` 确认；
  - 上帝视角点击可拉起 `MediaPreviewDialog` 进行全量调阅。
- **字号与弹窗规范达标**：清退所有 `text-[10px]` / `text-[11px]`，正文及表单标签基准达标（14px~16px），确认全站 0 原生弹窗。

**Non-Goals:**
- 不重写服务端 API（后端接口契约稳定完善，无需变更后端逻辑）。
- 不引入外部庞大的多媒体处理或富文本编辑器库，保持 Web 端极速首屏体验。
- 不修改移动端 Flutter 代码。

## Decisions

### 1. 端侧压缩架构：原生 HTML5 Canvas 独立工具化
- **决策**：新建 `web/src/utils/imageCompressor.ts`，封装 `compressImage(file: File, maxDimension = 1600, quality = 0.82): Promise<File>`。
- **理由**：
  - 严格契合 ADR 0003 要求（长边 ≤1600px，JPEG 质量 80%~85%）；
  - 移动设备或桌面浏览器均原生支持 `createImageBitmap` / `CanvasRenderingContext2D.drawImage`，零额外 npm 依赖，零 WASM 算力体积包负担；
  - 即使上传 20MB 原图，也能在客户端毫秒级降至 200KB~400KB，大幅节约家庭自建服务器与公网 DDNS 的带宽压力。
- **替代方案考虑**：
  - *使用 browser-image-compression 等三方库*：引入了冗余打包体积与 WebWorker 兼容层，本场景等比缩放 + JPEG 编码已足够轻量高效。

### 2. 空间管理模态设计：复用 `HouseRoomDialog` 并引入模式切换
- **决策**：将 `HouseRoomDialog.vue` 改造为支持 `mode: "create" | "edit"`，传入已有实体时自动预填名称与选中 Emoji 图腾。
- **理由**：
  - 避免创建重复的 `EditHouseDialog.vue` 和 `EditRoomDialog.vue`；
  - 统一 Emoji 图腾选取器和表单验证逻辑；
  - 将单文件代码量控制在 260 行以内，远低于 500 行工程红线。
- **替代方案考虑**：
  - *在侧边栏做行内直接内联编辑 (Inline editing)*：在小屏或树形列表展开时容易发生排版错位，且无法优雅呈现精美的 10+ 预设 Emoji 图腾网格。

### 3. TAR 备份下载鉴权：Axios Blob 管道方案
- **决策**：在 `web/src/api/index.ts` 中新增 `downloadBackupApi(id: number, filename: string)`：
  ```ts
  const res = await api.get(`/admin/backups/${id}/download`, { responseType: 'blob' });
  const blob = new Blob([res.data], { type: 'application/x-tar' });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.URL.revokeObjectURL(url);
  ```
- **理由**：
  - Axios 实例已有 request 拦截器注入 `Authorization: Bearer ${token}`，无需破坏现有接口鉴权契约；
  - 彻底解决浏览器原生 `<a href="...">` 跳转导致的 401 Unauthorized 阻断。
- **替代方案考虑**：
  - *修改后端支持 URL Query 参数携带 token*：会导致 JWT 凭证出现在服务器 access.log 或历史记录中，存在 URL 凭证泄露风险。

### 4. 生产环境账密防护：环境标识守卫
- **决策**：在 `LoginView.vue` 中使用 `v-if="isDev"` 包裹一键快速登录测试按钮区，其中 `const isDev = import.meta.env.DEV`。
- **理由**：
  - 开发和本地调试时依然能秒切 Alice/Bob/Admin 体验上帝视角；
  - 生产打包（`npm run build`）时 Vite 自动静态擦除（Tree-shaking）该分支，绝不向生产环境编译包泄露 `admin123456`。

### 5. 统一排版与无原生弹窗保障
- **决策**：
  - 对 `LoginView`、`GodViewDialog`、`BackupPanel`、`ThemeSwitcher`、`MediaPreviewDialog` 进行全量字号巡检与升级，消除 `text-[10px]` 与 `text-[11px]`；
  - 空间删除与备份删除统统接入 `ConfirmDialog`，传递对应警示文案与 `isDanger: true`。

## Risks / Trade-offs

- **[Risk] 部分老旧浏览器 Canvas `toBlob` 质量控制** → **Mitigation**: 提供高质量降级回退机制，默认捕获 JPEG 格式并校验返回 Blob 大小。
- **[Risk] 空间删除时级联删除其下物品与照片的不可逆性** → **Mitigation**: `ConfirmDialog` 中以加粗红色警示文案明确告知“该房屋/房间下的所有收纳物品及照片将永久清理”，防止误触。
- **[Risk] 单文件行数膨胀** → **Mitigation**: 严格遵守 <500 行红线，工具逻辑（如压缩、下载）全部下沉至 `utils/` 与 `api/`，组件仅负责视图组装。

