## 1. 全局软删除架构原则改造

- [x] 1.1 在 SQLAlchemy 核心数据表模型（`User`, `House`, `Room`, `Item`, `Category`, `Tag`）中确认并添加 `is_deleted` 布尔软删除字段（默认 False，建索引），验证模型迁移
- [x] 1.2 将后端现有的所有物理 `db.delete(...)` 改造为软删除标记（`entity.is_deleted = True`），并确保所有查询接口（列表、详情、FTS5检索）默认过滤已软删除数据
- [x] 1.3 移除数据表与接口中无意义的家庭成员枚举或生硬角色标签，普通用户仅以昵称与账号标识

## 2. 后端核心治理与灾备能力扩展

- [x] 2.1 在 `server/app/api/admin.py` 中实现管理员自身改密接口 `PUT /admin/password`，验证原密码校验与新口令哈希更新
- [x] 2.2 实现多维级联寻物查询服务 `god_view_advanced_search`（支持按用户、房屋、房间、分类、标签、关键词、时间范围多维过滤），严格保持 Admin 只读
- [x] 2.3 实现多媒体孤儿文件扫描与清理服务：遍历 `/data/media/` 对比数据库有效附件，统计未引用的孤儿文件并支持管理员物理抹除
- [x] 2.4 实现三模 TAR 灾难恢复引擎：支持从已有记录恢复、接收 Web 上传 TAR 恢复，以及扫描服务器指定目录 `/data/media/backups/import/` 解析校验结构后安全恢复（含 SQLite 恢复、媒体解压与 FTS5 索引重建）

## 3. Web API 客户端封装与类型定义

- [x] 3.1 在 `web/src/types/index.ts` 中补充多维寻物查询参数、孤儿文件审计结果、服务器导入备份项及管理员改密参数的 TypeScript 类型定义
- [x] 3.2 在 `web/src/api/index.ts` 中封装新接口（`adminUpdatePasswordApi`, `godViewAdvancedSearchApi`, `scanOrphanMediaApi`, `cleanOrphanMediaApi`, `restoreBackupApi`, `restoreFromUploadApi`, `scanImportBackupsApi`, `restoreFromImportApi`）

## 4. UI 页面空间与标题栏彻底重构

- [x] 4.1 重构 `web/src/components/space/SpaceAnchorBar.vue`：充分利用标题栏绿框空间，左侧展示当前管理模块名称，中间紧凑呈现 4 组系统指标胶囊，右侧增加 Admin 自身改密入口 (`KeyRound`)
- [x] 4.2 重构 `web/src/components/space/HouseRoomSidebar.vue`：消除冗余说明，提供清晰的 4 项一级独立单选路由菜单（👥 用户账号管理、🔍 多维托底寻物、📦 数据灾备恢复、🧹 存储孤儿清理）
- [x] 4.3 重构 `web/src/views/MainView.vue` 与 `web/src/components/admin/AdminDashboard.vue`：彻底删除“系统管理中枢控制台”大黄横幅与重复 Tab 栏，100% 满屏展示当前专属操作面板
- [x] 4.4 优化 `web/src/components/admin/UserManagementPanel.vue`：彻底删除用户卡片上的“家庭成员”生硬标签（保留系统管理员标记），界面更加清爽专业

## 5. 专属独立管理面板开发

- [x] 5.1 创建 `web/src/components/admin/MultiDimensionalSearchPanel.vue`，实现用户 ➔ 房屋 ➔ 房间级联下拉组合分类、标签、关键词与日期的托底寻物工作台，只读调阅详情
- [x] 5.2 创建 `web/src/components/admin/BackupRestorePanel.vue`，集成历史快照列表、一键备份、直接恢复、浏览器上传恢复、及服务器目录 `/data/media/backups/import/` 扫描解析一键恢复
- [x] 5.3 创建 `web/src/components/admin/MediaCleanupPanel.vue`，呈现多媒体存储分布、孤儿附件一键扫描统计、及二次确认安全物理清理

## 6. 端到端系统验证与部署发布

- [x] 6.1 运行前端类型检查与生产构建 `npm run build`，确保无报错、无明文泄密、无原生 `alert/confirm`
- [x] 6.2 扩展后端测试覆盖软删除不丢失、多维级联检索、三模恢复、孤儿清理及 Admin 改密逻辑
- [x] 6.3 运行 `openspec validate admin-system-governance --strict` 验证规范一致性
- [x] 6.4 部署至 186 服务器并执行健康检查与端到端实测验证

## 7. 界面细节微调、数据库解耦与备份体验深化

- [x] 7.1 前端样式与按钮协调：多维寻物“重置条件”按钮增加小刷子/清空图标 (`Eraser`/`RotateCcw`)，字号统一为 `text-sm font-bold` 与“开始检索”保持协调
- [x] 7.2 用户管理卡片紧凑排版：将 `grid-cols-1 md:grid-cols-2` 调整为更紧凑的响应式 3~4 列布局（`grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`），消除卡片横向过宽与大面积空旷感
- [x] 7.3 数据库文件更名为通用功能名 `items.db`：在后端配置与数据目录迁移 `antusuoji.db` ➔ `items.db`，升级 TAR 备份打包与恢复兼容性（兼容解析历史 `antusuoji.db`）
- [x] 7.4 备份防重复提交锁与交互完善：前端一键生成备份增加弹窗确认与禁用加载态，后端在 `backup_service.py` 增加并发互斥锁（已有正在运行备份时禁止重复提交并返回 409）
- [x] 7.5 历史备份记录表格分页与防膨胀清理：备份记录表格增加分页（默认每页 10 条），恢复一键清理过期备份功能，保留策略改为保留最近 3 份
- [x] 7.6 全站文案去中二化与去大词：排查全站页面与侧边栏文案，删除“全景收纳”、“数据灾备与三模恢复”等虚浮大词，软件名称统一纯粹展示为“物迹”
- [x] 7.7 指标统计下移至面板小标题栏：顶栏数量统计从全局顶栏中剥离，移入管理面板自身的小标题栏空白处展示

## 8. 默认密码规范与物品分类模板治理中枢

- [x] 8.1 调整 Admin 默认初始化密码为 `admin123`（更新 `seed_data.py` 及相关测试用例）
- [x] 8.2 创建 `CategoryTemplate` 数据表模型与数据库迁移，首次建库导入 14 种预设分类模板数据
- [x] 8.3 实现分类模板管理后端接口（`GET/POST/PUT/DELETE /api/admin/category-templates` 及状态启停 `PATCH .../status`）
- [x] 8.4 重构新用户初始化分类逻辑：从数据库拉取激活状态的模板集合动态生成新用户私有分类，替代写死逻辑
- [x] 8.5 创建前端 `CategoryTemplatePanel.vue` 物品分类管理面板，并在 `HouseRoomSidebar.vue` 增加导航入口
- [x] 8.6 运行端到端测试与构建，部署至 186 服务器并验证

## 9. 物品分类序号可视化与拖拽/上下箭头重排序

- [x] 9.1 后端分类模板重排序接口：在 `server/app/api/category_templates.py` 中实现 `PUT /api/admin/category-templates/reorder`，接收 ordered ID 列表并原子更新模板 `sort_order`
- [x] 9.2 后端用户分类重排序接口：在 `server/app/api/items.py` 中实现 `PUT /api/items/categories/reorder`，接收 ordered ID 列表并原子更新当前用户的分类 `sort_order`
- [x] 9.3 Admin 物品分类管理面板卡片序号呈现与交互：在 `CategoryTemplatePanel.vue` 中每张分类卡片展示醒目序号标签（如 `#1`），并集成上下移动箭头与拖拽调序
- [x] 9.4 普通用户分类管理页面扩展：在 `CategoryManageDialog.vue` 中支持分类序号标签展示、上下箭头排序微调以及拖拽卡片/列表项重排序交互
- [x] 9.5 前端 API 封装与主页分类选择器联动：封装 `reorderCategoryTemplatesApi` 与 `reorderUserCategoriesApi`，重排序后即时同步刷新主页 `CategoryFilterSelect.vue` 与卡片展示
- [x] 9.6 全流程端到端自动化测试与 186 服务器部署验证：扩展 E2E 测试覆盖管理员与普通用户两级分类重排序接口，执行前端打包与部署发布

