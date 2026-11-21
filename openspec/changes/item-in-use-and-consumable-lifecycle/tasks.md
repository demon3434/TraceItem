# Tasks

## 1. 后端数据模型与数据库迁移

- [x] 1.1 在 `server/app/models/item.py` 与 `server/app/models/attachment.py` 中为 `Item` 新增 `status`（默认 `'stored'`）、`storage_house_id`、`storage_room_id`、`storage_location_detail`、`status_updated_at` 字段，为 `Attachment` 新增 `scene` 字段（默认 `'storage'`），保持单文件严格低于 500 行。
- [x] 1.2 在 `server/app/db/init_db.py` 中添加幂等 `PRAGMA table_info` 兼容性迁移逻辑，为存量 `items` 与 `attachments` 表平滑补齐新列及索引。
- [x] 1.3 更新 `server/app/schemas/item.py` 与 `server/app/schemas/attachment.py`，将 `ItemCreate` / `ItemUpdate` 的 `quantity` 校验放宽至 `ge=0`，新增 `ItemTakeOutPayload`、`ItemPutBackPayload` 及 `ItemOut` 中的 `status`、`storage_attachments`、`storage_path_display` 等字段。

## 2. 后端生命周期服务与接口实现

- [x] 2.1 新建独立服务模块 `server/app/services/item_lifecycle_service.py`（控制 <500 行），实现 `take_out_item`（校验至少 1 张 `in_use` 图片、保存 `storage_*` 快照、更新当前房间与位置备注、写入 `in_use` 附件并同步 FTS5）与 `put_back_item`（恢复快照或更新新位置、事务提交后批量调用 `delete_physical_attachment` 清理 `in_use` 附件、支持局部替换/增删 `storage` 附件）。
- [x] 2.2 在 `server/app/api/items.py` 中新增 `POST /api/items/{item_id}/take-out` 与 `POST /api/items/{item_id}/put-back` 接口，并在 `GET /api/items` 中增加可选 `status` 筛选参数；同时确保 `ItemOut` 在 `in_use` 状态下默认展示 `in_use` 组附件。
- [x] 2.3 编写并运行后端单元测试（覆盖取出强校验至少 1 张图、原位置快照保留与恢复、归还自动清理 `in_use` 物理文件、`quantity=0` 创建与更新、以及 `status` 筛选）。

## 3. 移动端 (Flutter) 适配与交互实现

- [x] 3.1 同步更新移动端 `Item` / `Attachment` 数据模型与离线同步队列字段（`status`、`scene`、`quantity >= 0`、`take_out` / `put_back` 操作支持）。
- [x] 3.2 改造移动端物品卡片组件，在 `in_use` 状态下仅于封面右上角叠加紧凑 Lucide `PackageOpen` 图标 + 6px 主题色圆点微徽章（无“使用中”汉字），且 `quantity == 0` 时不渲染多余状态标签。
- [x] 3.3 复用编辑表单拆分子组件实现“取出使用登记页”：基本属性（名称、品牌、分类、标签、数量）只读锁定，开放当前房屋/房间与位置备注编辑，附件区清空并强制校验至少提交 1 张照片。
- [x] 3.4 在物品详情页底栏按“数量调整 -> 编辑 -> 取出/归还（方案 A 纯图标） -> 删除”顺序排布；数量由 `1` 减至 `0` 时连续弹出两次 `ShadDialog` 确认删除（取消则保持 `0`）；归还收纳采用独立全屏页面 `ItemPutBackScreen` 提供“原位放回”与“更换位置/替换照片”操作，全部提示使用 `CustomDialogs.showToast`。

## 4. Web 端 (Vue 3) 适配与交互实现

- [x] 4.1 改造 Web 端 `ItemCard.vue`，在 `in_use` 状态下于封面角落显示紧凑 Lucide `PackageOpen` 图标微徽章（无汉字），`quantity == 0` 时不增加额外状态标签，支持列表顶部按状态筛选待归位物品。
- [x] 4.2 基于 `shadcn-vue` Dialog 拆分实现独立组件 `ItemTakeOutDialog.vue` 与 `ItemPutBackDialog.vue`（单文件 <300 行），分别支持只读锁定基础属性+强制拍图取出，以及原位放回/换位重拍归还，全程零原生 `alert()` / `confirm()`。
- [x] 4.3 在 Web 端 `ItemCard.vue` 右上角数量胶囊融合快捷 `-1 / +1` 步进器，并在左上角悬浮胶囊的「编辑」与「删除」之间放置方案 A 纯图标取出/归还按钮（不放入详情预览弹窗），同时实现数量归零两步 `shadcn-vue` 确认 Dialog 与统一 Toast 提示。

## 5. 全端联调与规范校验

- [x] 5.1 检查所有新增及修改的 Python、Dart、Vue 文件行数均严格低于 500 行，且无任何原生 `alert` / `confirm` / `prompt` 或 sub-12px 字体。
- [x] 5.2 运行全端相关测试与静态检查（后端 `pytest`、移动端 `flutter analyze` / `flutter test`、Web 端类型检查与构建），确认全部通过。
