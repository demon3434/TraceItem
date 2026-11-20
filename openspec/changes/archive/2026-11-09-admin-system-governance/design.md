## Context

图觅 (TraceItem) 是一款家庭全景收纳管理系统。系统管理员 (Admin) 的核心定位是：**系统级运维托底、全局穿透寻物、灾难冷备与多媒体存储健康管家**。
管理员绝不应该越权篡改普通用户的私有账本数据，各用户数据之间保持 100% 独立私有与隐私隔离。

## Goals / Non-Goals

**Goals:**
1. **全局软删除架构 (Soft-Delete)**：一切实体（用户、空间、物品、分类等）的“删除”操作必须将状态置为已删除（`is_deleted = True`），杜绝数据库物理破坏。
2. **多维级联托底寻物工作台**：Admin 专享多维级联检索（选择用户 ➔ 级联房屋 ➔ 级联房间 ➔ 分类 ➔ 标签 ➔ 关键词 ➔ 时间范围），专职托底查物，全流程严格只读。
3. **孤儿附件磁盘物理清理**：对比 SQLite 与 `/data/media/` 实际文件，提供孤儿文件扫描与一键清理。
4. **三模闭环 TAR 灾备恢复**：支持历史记录恢复、浏览器小包上传恢复、以及针对超大文件的“SCP 上传至 `/data/media/backups/import/` 后 Web 扫描校验结构一键恢复”。
5. **Admin 自身修改密码**：在顶部操作区支持管理员自主修改密码。
6. **UI 页面空间彻底解放**：
   - 移除用户卡片上的“家庭成员”无效角色标签；
   - 彻底删除“系统管理中枢控制台”大黄横幅；
   - 4 组系统指标压缩整合进顶部标题栏 (`SpaceAnchorBar`)；
   - 消除内容区重复的 Tab 栏，左侧侧边栏作为唯一独立菜单，主内容区 100% 满屏展示专属操作台。

**Non-Goals:**
1. **Admin 篡改用户数据**：Admin 严禁修改普通用户的物品、空间或备注，保持纯只读。
2. **多用户跨账本协同共享**：暂不实现跨用户可见或公共置顶，各账本绝对物理隔离。

## Decisions

### 1. 全局软删除标准落地
- 在各实体表模型（`User`, `House`, `Room`, `Item`, `Category`, `Tag`）中确认/增加 `is_deleted` 字段（布尔类型，默认 `False`，带索引）；
- 所有业务查询自动附加 `.filter(Model.is_deleted == False)`；
- 删除 API 不调用 `db.delete(entity)`，统一执行 `entity.is_deleted = True; db.commit()`。

### 2. 多维级联托底寻物组件与 API (`MultiDimensionalSearchPanel.vue`)
- 后端新增 `GET /api/admin/god-view/filter-options`：返回全量用户列表及其名下的房屋与房间层级结构树，便于前端实现即时无网络延迟的三级联动选择；
- 后端扩展 `GET /api/admin/god-view/advanced-search`：支持综合过滤参数：
  - `user_id?: int`
  - `house_id?: int`
  - `room_id?: int`
  - `category_id?: int`
  - `tag_name?: str`
  - `keyword?: str`
  - `start_date?: str`, `end_date?: str`
  - `page: int`, `page_size: int`
- 前端界面采用温润大圆角卡片布局，顶部为紧凑的多维级联筛选器，下方为全屏资产列表，点击即调阅多媒体现场指引。

### 3. 多媒体孤儿文件扫描与清理引擎
- **扫描逻辑**：
  1. 收集数据库中所有有效 `Attachment.file_path` 和 `thumbnail_path`，构建集合 `active_files`；
  2. 深度遍历磁盘物理目录 `/data/media/`（排除 `backups/` 目录）；
  3. 识别出不在 `active_files` 中的磁盘物理文件，统计总文件数与总字节大小；
- **清理逻辑**：管理员确认后，批量 `os.remove` 孤儿文件并清理空目录。

### 4. TAR 备份与恢复机制、通用数据库命名与并发防重
- **数据库通用命名 (`items.db`)**：
  - 核心数据库文件与软件品牌名彻底解耦，统一命名为通用的功能名称 `items.db`；
  - TAR 包打包快照时放入 `items.db`；
  - 恢复与扫描逻辑保持向下兼容，若解压包中存在 `items.db` 或历史 `antusuoji.db` 均能正确识别与恢复。
- **并发互斥与一键生成确认**：
  - 后端在 `backup_service.py` 中引入 `threading.Lock()`，当已有备份任务在执行时，新的生成请求直接返回 HTTP 409（“已有备份任务正在进行中，请勿重复提交”）；
  - 前端一键生成备份增加 `ConfirmDialog` 确认弹窗；确认后按钮置灰禁用，显示“正在打包生成备份中...”，彻底杜绝误触与连击。
- **防膨胀清理与分页呈现**：
  - 恢复过期备份清理功能，保留策略改为保留最近 **3 份** 快照；
  - 备份记录表格支持分页切换，默认每页 10 条，避免列表无限纵向拉长。

### 5. UI 细节打磨、平实文案与空间重构
- **文案去中二化与去大词**：
  - 彻底去除“全景收纳”、“数据灾备与三模恢复”等虚浮词汇，采用朴素平实的工程化文案（如“数据备份与恢复”）；
  - 软件名称纯粹展示为“物迹”，去除多余修饰。
- **指标统计下移至面板小标题栏**：
  - 顶栏红框中的 4 组数量统计从全局顶栏中剥离，移入各管理工作台自身的小标题栏空白处，随各工作台自然呈现。
- **多维寻物重置按钮调优**：
  - “重置条件”按钮增加清空/小刷子图标 (`RotateCcw` / `Eraser`)，字号统一为 `text-sm font-bold`，与“开始检索”保持高度协调。
- **用户卡片紧凑排布**：
  - 用户账号管理卡片网格调整为更紧凑的响应式 3~4 列网格 (`grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4`)，消除卡片横向过宽与信息空旷感。
- **`SpaceAnchorBar.vue` (顶部标题栏)**：
  - 仅保留当前工作区标题、主题切换器、**Admin 修改密码按钮 (`KeyRound`)** 与退出登录按钮，界面极简干净。
- **`HouseRoomSidebar.vue` (左侧菜单)**：
  - 充当纯净的 4 级单选路由菜单，选中某项直接切换主屏幕内容。
- **`MainView.vue` (主内容区)**：
  - 彻底删除黄色横幅与页面内 Tab 条；
  - 根据侧边栏选中的菜单，100% 满屏渲染对应的独立子面板。
- **`UserManagementPanel.vue`**：
  - 剔除普通用户的“家庭成员”生硬标签，仅保留系统管理员标记。
- **`CategoryTemplatePanel.vue` (新增)**：
  - 专供管理员进行系统级分类模板治理，展示分类卡片、增删改停抽屉弹窗与温润操作流。
- **`HouseRoomSidebar.vue`**：
  - 侧边栏菜单增加【🏷️ 物品分类管理】独立工作台入口。

### 7. 分类模板中枢设计与动态新用户派生机制

```
[ Admin 后台 ] ── 增/删/改/停 ──> [ CategoryTemplate 表 ]
                                            │ (动态读取有效模板)
                                            ▼
[ 新用户注册 / 开户 ] ───────> [ 生成该用户私有 Category 表 ]
```

- **数据模型**：
  - `CategoryTemplate`: `id`, `name`, `icon`, `color`, `sort_order`, `is_active`, `is_deleted`, `created_at`。
- **初始化种子**：首次部署时将预设的 14 个分类存入 `category_templates` 表，Admin 可持续编辑维护。
- **新用户初始化**：当新用户被创建时，从 `CategoryTemplate` 查询当前处于启用状态（`is_active=True` 且 `is_deleted=False`）的模板项进行拷贝。

### 8. 分类序号可视化与双模排序交互设计 (拖拽 + 箭头微调)

- **持久化接口设计**：
  - Admin 模板重排序：`PUT /api/admin/category-templates/reorder`，接收 `ordered_ids: List[int]`，事务内批量重置 `sort_order` 为 `[1, 2, 3, ...]`。
  - 用户私有分类重排序：`PUT /api/items/categories/reorder`，接收 `ordered_ids: List[int]`，在所属 `user_id` 范围校验下事务内批量重置 `sort_order`。
- **交互与无依赖拖拽**：
  - 前端采用原生 HTML5 Drag & Drop（`draggable="true"`）事件流（`dragstart`, `dragover`, `drop`），轻量无臃肿第三方外部依赖；
  - 每张卡片/列表项保留明显的【向上/向下微调按钮】作为低门槛兜底操作；
  - 卡片左上角配备多巴胺轻胶囊标签（如 `#1`、`#2`），视觉次序一目了然。

## Risks / Trade-offs

- **[数据恢复导致当前会话断开]**：
  - *对策*：恢复成功后，前端清理 localStorage 并弹出温馨提示：“系统数据已从 TAR 备份恢复，请重新登录”，自动跳转登录页。
- **[超大文件上传超时]**：
  - *对策*：针对大备份包明确引导使用 SCP 上传至指定目录，通过模式 C 扫描恢复，绕过浏览器 HTTP 传输上限。
