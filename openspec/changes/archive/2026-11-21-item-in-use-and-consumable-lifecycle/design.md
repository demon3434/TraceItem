# Design

## Context

当前 `Item` 模型仅维护单一静态位置（`house_id`、`room_id`、`location_detail`）与单组 `Attachment`，且 `ItemCreate` / `ItemUpdate` 校验 `quantity >= 1`。现有 `media_service.py` 已提供 `delete_physical_attachment` 工具函数用于清理失效多媒体文件，`init_db.py` 采用幂等 `PRAGMA table_info` 检查执行 SQLite 兼容性列迁移。

（变更动机与业务背景见 `proposal.md`。）

## Goals / Non-Goals

**Goals:**
- 以最小表结构侵入实现物品 `stored` / `in_use` 双态流转及原收纳位置快照恢复。
- 通过 `Attachment.scene`（`'storage'` | `'in_use'`）实现两套多媒体附件完全隔离与归还时自动物理清理。
- 支持 `quantity >= 0` 的消耗品快捷步进与归零二次确认删除。
- 保持移动端离线同步队列（`version` + `ItemSyncOp`）与 FTS5 全文检索无缝兼容。

**Non-Goals:**
- 不支持“借出给他人”流程及借还人管理。
- 不保留 `in_use` 期间的历史附件归档（归还即清理销毁）。
- 不为 `quantity == 0` 或 `in_use` 在卡片上增加长文本状态标签。

## Decisions

### 1. 数据模型扩展与状态快照字段
- **选择**：在 `items` 表新增 `status VARCHAR(20) NOT NULL DEFAULT 'stored'`、`storage_house_id INTEGER`、`storage_room_id INTEGER`、`storage_location_detail TEXT DEFAULT ''`、`status_updated_at DATETIME`；在 `attachments` 表新增 `scene VARCHAR(20) NOT NULL DEFAULT 'storage'`。
- **理由**：
  1. `Item` 的 `house_id / room_id / location_detail` 始终代表**当前有效位置**，检索、上帝视角、空间筛选与 FTS5 索引无需任何双分支判断即可 100% 命中当前位置。
  2. 取出时把旧 `house_id / room_id / location_detail` 写入 `storage_*` 快照列；归还时若选“原位放回”则回填快照并清空 `storage_*`，若选“新位置”则直接写入新位置并清空 `storage_*`。
  3. `scene` 采用字符串（`'storage'` / `'in_use'`）与现有 `Attachment.media_type`（`'image' | 'audio' | 'video'`）风格一致，便于查库与离线同步排错。
- **备选方案**：单独建 `item_usage_records` 流水表。因当前无需长期借还审计流水，单表快照 + `scene` 隔离更轻量，且兼容现有 `Item` 乐观锁与离线同步。

### 2. 状态流转接口设计（专用端点 vs 复用 PUT）
- **选择**：在 `server/app/api/items.py` 新增两个语义化端点：
  - `POST /api/items/{item_id}/take-out`：校验当前为 `stored`，强制要求请求体携带至少 1 张图片附件（存入 `scene='in_use'`），锁定基础属性不改，仅更新当前 `house_id / room_id / location_detail` 并保存 `storage_*` 快照。
  - `POST /api/items/{item_id}/put-back`：校验当前为 `in_use`，支持 `restore_original: bool`（一键原位放回）或传入新 `house_id / room_id / location_detail`，支持对 `storage` 组附件执行增量增删（`added_storage_attachments` / `removed_attachment_paths`），并自动删除全部 `scene='in_use'` 附件记录及调用 `delete_physical_attachment` 清理磁盘文件。
- **理由**：专用端点能把“取出必须至少 1 张图”、“基础属性只读”、“归还自动销毁 `in_use` 附件”等业务不变量收拢在服务端 `item_service.py`（或拆分的 `item_lifecycle_service.py`）事务中，避免 `PUT /api/items/{id}` 逻辑膨胀超过 500 行。
- **兼容处理**：在 `GET /api/items` 与 `GET /api/items/{id}` 返回的 `ItemOut` 中，`attachments` 默认返回当前生效组（`in_use` 态返回 `in_use` 组，同时可附带 `storage_attachments` 供归还弹窗预览；`stored` 态返回 `storage` 组），使现有列表卡片渲染零改造即可展示正确封面。

### 3. 极简 UI 标识、方案 A 复合图标与全屏归还页
- **选择**：
  - 物品卡片仅在 `status == 'in_use'` 时于封面角落叠加紧凑半透明磨砂微胶囊（仅包含 Lucide `PackageOpen` 图标 + 6px 主题色圆点），不显示汉字。
  - 移动端详情页底栏采用“数量调整 -> 编辑 -> 取出/归还 -> 删除”顺序；Web 端则将数量步进融合物品卡片右上角数量胶囊，并将取出/归还按钮置于卡片左上角悬浮胶囊的「编辑」与「删除」之间（不放入详情预览弹窗）。两者取出/归还均采用**方案 A 纯矢量图标**（开箱+↗出库 / 箱子+↙归位），不占文字宽度。
  - 移动端归还收纳采用独立全屏页面 `ItemPutBackScreen`（而非底部抽屉），保证更换位置与附件选择时拥有充足的表单填写空间。
  - 取出使用页/弹窗复用现有物品编辑表单逻辑，将名称、品牌、分类、标签、数量设为只读禁用，清空附件选择器并校验至少 1 张图片。
  - 数量步进在 `1 -> 0` 时由前端串联两次 `ShadDialog` / `shadcn-vue` Dialog 确认，用户取消则提交 `quantity: 0`；两次均确认则调用软删除接口。

### 4. 缩略图清晰度与体积平衡
- **选择**：在 `server/app/services/media_service.py` 将缩略图长边从 `300px` 提升至 `min(600, max(w, h))`，重采样改为 `LANCZOS`，JPEG 质量调整为 `82`（移动端 `memCacheWidth: 600`），在不显著增加存储开销（单张约 25~45KB）的前提下消除卡片封面模糊。

### 4. 单文件行数控制
- `server/app/services/item_service.py` 已有近 400 行，新增的取出/归还生命周期逻辑独立拆分为 `server/app/services/item_lifecycle_service.py`，确保所有 Python、Dart、Vue 文件严格低于 500 行。

## Risks / Trade-offs

- **[Risk] 离线状态下执行取出/归还与桌面端同时编辑冲突** → 复用现有 `Item.version` 乐观锁校验，`take-out` / `put-back` 接受可选 `expected_version` 与 `client_op_uuid` 幂等键，冲突时返回 409 由移动端同步队列按既有冲突弹窗处理。
- **[Risk] 归还时删除 `in_use` 物理文件若数据库提交失败导致文件丢失** → 先完成数据库事务提交（删除 `Attachment` 行并更新 `Item`），事务成功后再批量执行 `delete_physical_attachment` 清理磁盘文件。
- **[Risk] 取出时允许更换房间，若用户选了跨房屋/已停用房间** → 在 `take-out` 与 `put-back` 中复用 `space_service` / `item_service` 的房屋与房间归属及 `is_deleted == False` 校验。

## Migration Plan

1. 在 `server/app/db/init_db.py` 增加幂等 `PRAGMA table_info(items)` 与 `PRAGMA table_info(attachments)` 检查，自动 `ALTER TABLE` 添加 `status`、`storage_house_id`、`storage_room_id`、`storage_location_detail`、`status_updated_at` 与 `attachments.scene`，旧数据平滑默认 `status = 'stored'`、`scene = 'storage'`。
2. 后端先上线并保持旧客户端 `PUT /api/items/{id}` 向后兼容（`quantity` 放宽至 `ge=0`），随后发布 Web 端与移动端更新。

