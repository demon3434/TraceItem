# Proposal

## Why

当前系统中的房屋与房间采用无条件级联软删除机制：一旦用户误触确认删除某个非空房屋或房间，其名下全部收纳物品与现场凭证都会被连带隐藏，存在较高的误操作风险；同时，房屋与房间缺少类似分类的启停（`is_active`）机制，当用户不再向旧房屋、封箱房间或搬离住所录入新物品但仍希望保留历史物品供日后查找时，无法在不删除数据的前提下将其从日常录入选择器中收起。

## What Changes

- **删除安全拦截（非空保护）**：
  - 房间内存在任何未删除物品（`Item.is_deleted == False`）时，服务端与客户端均**禁止删除该房间**，并返回明确提示引导用户先迁移/删除物品或改为「停用房间」。
  - 房屋内存在任何未删除物品时，服务端与客户端均**禁止删除该房屋**；当房屋下不存在任何未删除物品（即使包含空房间）时，允许删除该房屋并连带清理空房间。
- **房屋与房间启停机制（`is_active`）**：
  - 为 `House` 与 `Room` 模型新增 `is_active` 状态字段（默认 `true`），并在 SQLite 初始化脚本中提供兼容性迁移。
  - **状态继承与独立保留**：房屋与房间各自独立存储 `is_active`；房间实际可录入状态遵循 `house.is_active && room.is_active`，停用房屋时不篡改下属房间的原始 `is_active` 值，以便重新启用房屋时保留各房间的既有启停配置。
  - **录入隔离与旧物兼容**：新建/移动物品选择器仅展示有效启用空间（服务端同步拦截向已停用或已删除房屋/房间创建房间或录入/迁入物品）；编辑已有物品时若其原位置已停用，保留该当前选项以防修改其他字段时丢失归属。
  - **首页浏览可找回**：Web 端空间侧边栏与移动端首页空间筛选器默认收起/隐藏已停用空间，并提供显式的「显示已停用空间」切换开关，让用户可随时展开查看已停用空间内的历史物品。
- **统一交互组件约束**：
  - 全端严禁使用浏览器原生 `alert()`、`confirm()`、`prompt()`。Web 端使用自定义 `ConfirmDialog` 与 Toast；移动端使用封装的 `CustomDialogs.showConfirm`（`ShadDialog`）、`CustomDialogs.showModalSheet`（`ShadSheet`）与 `CustomDialogs.showToast`。

## Capabilities

### New Capabilities
- `space-lifecycle-governance`: 定义跨端通用的房屋/房间删除非空拦截规则、启停（`is_active`）状态模型、写入校验与数据兼容性迁移规范。

### Modified Capabilities
- `web-space-management`: **BREAKING** 将原有的无条件级联删除改为非空拦截删除（有物品禁止删除并引导停用），并新增 Web 端房屋/房间启停操作、录入选择器过滤及空间侧边栏「显示已停用空间」开关。
- `mobile-navigation-and-spaces`: 新增移动端空间管理页的房屋/房间启停操作（收拢于 `SpaceActionSheet` 半屏抽屉）、删除拦截引导、录入位置选择器过滤以及首页「显示已停用空间」开关。

## Impact

- **后端 (`server/`)**：`app/models/space.py`、`app/db/init_db.py`、`app/schemas/space.py`、`app/services/space_service.py`、`app/services/item_service.py`、`app/api/houses.py`、`app/api/rooms.py` 及对应单元测试。
- **Web 端 (`web/`)**：`src/api/index.ts`、`src/types/`、`src/views/MainView.vue`、`src/components/space/SpaceTreeNav.vue`、`src/components/space/SpaceTreeRoomList.vue`、`src/components/space/HouseRoomSidebar.vue`、`src/components/item/ItemDialog.vue`。
- **移动端 (`mobile/`)**：`lib/models/models.dart`、`lib/core/api_service.dart`、`lib/screens/space_manage_screen.dart`、`lib/widgets/space_action_sheet.dart`、`lib/widgets/space_manage_cards.dart`、`lib/widgets/home_filter_sheets.dart`、`lib/widgets/item_edit_pickers.dart`、`lib/screens/item_edit_screen.dart`。
- **交付验证**：变更实施完成后需重新部署至 186 环境，并按需构建 ARMv8 (`arm64-v8a`) Release APK。

