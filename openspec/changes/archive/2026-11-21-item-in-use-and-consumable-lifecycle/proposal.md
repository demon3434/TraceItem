# Proposal

## Why

家庭物品中存在大量换季或阶段性使用的物件（如电风扇、棉鞋），它们平时固定收纳于储物间或收纳盒，取出使用数月期间物品并未消失、不能删除，但若台账仍显示旧收纳位置与旧箱子照片会导致误找；归还收纳时位置与收纳盒又可能发生变化，需要更换照片。此外，膏药、日用囤货等消耗品存在频繁的领用扣减与归零场景，现有系统缺乏低摩擦的取出/归还状态流转与数量归零管理能力。

## What Changes

- **物品取出与归还生命周期**：为 `Item` 引入 `status`（`stored` 已收纳 / `in_use` 已取出使用）及原收纳位置快照（`storage_house_id`、`storage_room_id`、`storage_location_detail`），支持按状态筛选待归位物品。
- **双组多媒体附件隔离 (`Attachment.scene`)**：为 `Attachment` 新增字符串字段 `scene`（`'storage'` | `'in_use'`，默认 `'storage'`）。
  - **取出使用 (`stored -> in_use`)**：打开专属取出登记视图（复用编辑表单布局），名称、品牌、分类、标签、数量等基础属性只读带入不可修改，允许修改当前所在的房屋/房间与位置备注（`location_detail`），附件区清空并强制至少提交 1 张当前实拍照片（可选视频/语音），存入 `scene = 'in_use'`；原 `storage` 组附件与原收纳位置在后台完整保留。
  - **归还收纳 (`in_use -> stored`)**：自动失效并物理清理全部 `scene = 'in_use'` 附件，切回原收纳位置快照与 `scene = 'storage'` 附件，同时支持一键原位放回或修改收纳位置、局部替换旧附件。
- **极简无字卡片标识**：物品卡片在 `in_use` 状态下不显示“使用中”三个汉字，仅在封面/标题角落以紧凑 Lucide 图标（如 `PackageOpen` + 微光点）标识已取出状态，保持界面清爽。
- **消耗品数量快捷步进与归零二次确认**：放开 `ItemCreate` / `ItemUpdate` 的 `quantity` 校验下限至 `ge=0`，提供快捷 `-1 / +1` 操作；当数量从 `1` 减至 `0` 时触发二次确认弹窗（`ShadDialog` / `shadcn-vue` Dialog），用户确认两次后执行软删除；若用户拒绝删除则保持 `quantity = 0`，且不在物品卡片上增加多余状态标签。
- **UI 组件规范**：移动端采用 `ShadSheet`（归还/操作抽屉）、`ShadDialog`（数量归零二次确认）与 `CustomDialogs.showToast`；Web 端采用 `shadcn-vue` Dialog / Sheet / Toast，全端 100% 使用 Lucide Icons，严禁任何浏览器原生 `alert()`、`confirm()`、`prompt()`。

## Capabilities

### New Capabilities
- `item-lifecycle-management`: 定义物品的 `stored` / `in_use` 双态流转、原收纳位置快照与恢复、`Attachment.scene` 双组附件隔离与物理清理、以及消耗品 `quantity >= 0` 快捷步进与归零二次确认删除行为。

### Modified Capabilities
- `mobile-space-and-item-management`: 补充移动端物品卡片极简 `in_use` 图标角标、取出使用登记页（基础属性只读、允许改当前房间与备注、强制至少 1 张照片）、归还收纳 `ShadSheet` 抽屉与数量归零二次确认 `ShadDialog`。
- `web-core-experience`: 补充 Web 端物品卡片极简 `in_use` 图标角标、取出使用与归还收纳弹窗流程、消耗品快捷步进与归零二次确认弹窗（零原生弹窗）。

## Impact

- **后端 (`server/`)**：`Item` 与 `Attachment` 数据模型及 `init_db.py` 兼容性迁移脚本、`schemas/item.py` 与 `schemas/attachment.py`、`services/item_service.py`（取出/归还状态转换、物理清理 `in_use` 附件、FTS5 索引同步）、`api/items.py`（状态流转与列表筛选参数）。
- **移动端 (`mobile/`)**：`Item` / `Attachment` 模型与离线同步队列字段适配、物品卡片组件、取出使用页面/表单、归还收纳 `ShadSheet`、数量步进与二次确认 `ShadDialog`。
- **Web 端 (`web/`)**：物品卡片组件、取出使用/归还收纳 `shadcn-vue` 弹窗、数量步进与二次确认弹窗。

