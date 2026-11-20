## 1. 核心媒体修复与端侧智能压缩管道

- [x] 1.1 修复 `ItemCard.vue` 附件字段映射与路径：将 `file_type` 纠正为 `media_type`，将图片访问源修正为 `thumbnail_url` 或 `/api/media/file/{thumbnail_path}`，通过浏览器观察物品卡片实景缩略图、Mic 语音角标与 Video 视频角标均能正确呈现
- [x] 1.2 创建轻量端侧图片压缩工具 `web/src/utils/imageCompressor.ts`：利用原生 HTML5 Canvas 封装长边 ≤1600px 等比缩放与 JPEG (0.82) 压缩算法，通过选择 4K/大尺寸照片验证导出文件体积显著缩小且长宽受控
- [x] 1.3 升级 `ItemDialog.vue` 支持端侧智能压缩与已有附件展示：在选择照片后先经 Canvas 压缩再上传，并在编辑模式下保留与回显已有附件，验证新增大图极速上传且编辑保存不丢失原附件
- [x] 1.4 升级 `MediaPreviewDialog.vue` 多模态全景调阅能力与舒适字号：支持查看该物品名下的所有图片缩略图轮播切换、短视频播放与语音指引，并将说明与路径字号提升至 14px~16px (`text-sm`) 确保清晰可读

## 2. 空间全生命周期管理闭环

- [x] 2.1 扩展 `web/src/api/index.ts` 补齐空间更新方法：新增 `updateHouseApi(id, data)` 与 `updateRoomApi(id, data)`，验证其准确对应服务端的 `PUT /houses/{id}` 与 `PUT /rooms/{id}` 接口
- [x] 2.2 改造 `HouseRoomDialog.vue` 支持创建/编辑双模态：支持传入已有 House/Room 实体预填名称与选中 Emoji 图腾，单文件代码控制在 300 行以内，验证创建与编辑模式切换顺畅且图腾高亮准确
- [x] 2.3 在 `HouseRoomSidebar.vue` 空间树上集成编辑与删除操作入口：在房屋与房间悬浮态提供编辑与删除小图标，点击编辑唤起修改弹窗，点击删除触发危险确认事件
- [x] 2.4 在 `MainView.vue` 中绑定空间修改与删除处理逻辑：删除空间强制接入 `ConfirmDialog` 进行级联删除告警，验证确认后调用 `deleteHouseApi`/`deleteRoomApi` 并实时刷新空间树与物品列表

## 3. 安全防护、鉴权下载与管理端增强

- [x] 3.1 消除 `LoginView.vue` 生产账密泄露隐患：将快速填充测试账号区域增加 `v-if="isDev"`（绑定 `import.meta.env.DEV`），并将表单标签字号升级为 14px (`text-sm`)，验证在生产构建包中彻底剔除管理员默认明文密码
- [x] 3.2 封装带有 Bearer 鉴权的 `downloadBackupApi`：在 `web/src/api/index.ts` 中通过 Axios Blob 流管道下载 TAR 文件，并在 `BackupPanel.vue` 中替换原生直链，验证下载 TAR 成功且无 401 拦截
- [x] 3.3 为 `BackupPanel.vue` 备份删除接入 `ConfirmDialog`：移除裸调删除逻辑，接入二次危险确认遮罩，并将其内部残存的 `text-[11px]` 升级为标准 `text-xs`/`text-sm`
- [x] 3.4 增强 `GodViewDialog.vue` 穿透调阅能力并清除违规字号：点击穿透结果项可直接调阅 `MediaPreviewDialog` 查看大图、视频与空间指引，并将归属标签中的 `text-[10px]` 升级为合规字号
- [x] 3.5 巡检 `ThemeSwitcher.vue` 清理 `text-[11px]`：将主题描述字号统一提升至合规清晰字号，运行全局正则搜索验证全端完全不存在 `text-[10px]`、`text-[11px]` 以及原生 `alert()`/`confirm()`

## 4. 全局工程行数与构建验证

- [x] 4.1 校验所有修改及新增的 Web 源码文件（`.vue`、`.ts`），运行行数统计脚本验证没有任何单个文件超过 500 行
- [x] 4.2 运行 `npm run build` 验证前端 TypeScript 类型检查与 Vite 静态资源生产打包 100% 成功通过

