## Why

目前 Web 端和移动端均缺少房屋之间以及房屋内部房间的可视化排序调整能力；同时移动端「房屋和房间」页面采用二级内嵌折叠列表，当用户拥有多个房屋时页面会被拉得很长、行内操作按钮拥挤，难以通过长按拖拽顺畅调整顺序。本次变更旨在补全后端原子批量重排能力，并为 Web 端与移动端分别设计符合平台操作直觉的房屋/房间排序与空间管理体验。

## What Changes

- **后端批量排序 API 与默认顺序修正**：
  - 新增 `PUT /api/houses/reorder` 与 `PUT /api/rooms/reorder` 接口，支持按用户作用域（及房间所属 `house_id` 作用域）原子更新 `sort_order`。
  - 修正新建房屋与房间未指定或传入默认 `sort_order` 时全部落为 `0` 的问题，自动追加至当前末尾（`max(sort_order) + 1`）。
- **移动端「房屋和房间」页面重构（方案 A）**：
  - 将原先二级内嵌展开结构重构为**单层扁平交互**：顶部为可横向滑动的房屋切换胶囊轨与「调整顺序」入口，下方主区域仅展示当前选中房屋下的功能房间列表。
  - 房间列表支持单层 `ReorderableListView` **长按整卡拖拽排序**（附带 `HapticFeedback.mediumImpact()` 触觉反馈），并支持点击「调整顺序」或长按房屋胶囊唤起 **`ShadSheet` 房屋排序抽屉**，对房屋列表进行单层长按拖拽排序。
  - 将每张房屋/房间卡片上拥挤的多个行内操作按钮收拢至统一 **`ShadSheet`** 操作菜单（查看空间物品、编辑、删除），删除操作继续沿用危险态 **`ShadDialog`** 确认，反馈提示使用 **`ShadToaster`**，严禁任何系统原生弹窗。
- **Web 端侧边栏显式「排序模式」**：
  - 在左侧空间侧边栏「我的空间层级」标题栏新增「排序 / 完成」模式切换按钮。
  - 进入排序模式后隐藏悬停增删改浮层，展示左侧 `GripVertical` 抓手与 `↑ / ↓` 微调按钮；严格隔离拖拽作用域（房屋仅在房屋层间重排，房间仅在同一所属房屋内部重排），每次落位或微调即时持久化并由自定义 Toast 反馈。
- **模块拆分与代码规范**：
  - 严格控制单文件 < 500 行，对移动端 `SpaceManageScreen` 和 Web 端 `HouseRoomSidebar.vue` 进行子组件拆分，全端统一使用 `shadcn_ui` / `shadcn-vue` 组件与 Lucide Icons。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mobile-navigation-and-spaces`: 重构移动端「房屋和房间」管理页布局为顶部房屋横向切换轨 + 单层房间长按拖拽列表 + `ShadSheet` 房屋排序抽屉，并新增基于 `PUT /api/houses/reorder` 与 `PUT /api/rooms/reorder` 的排序持久化与卡片 `ShadSheet` 操作菜单规范。
- `web-space-management`: 为 Web 端空间管理侧边栏新增显式「排序模式」（拖拽与上下微调），要求房屋间与房屋内房间排序作用域严格隔离并调用批量重排接口持久化。

## Impact

- **服务端**：`server/app/schemas/space.py`、`server/app/services/space_service.py`、`server/app/api/houses.py`、`server/app/api/rooms.py` 及对应后端测试。
- **Web 端**：`web/src/api/index.ts`、`web/src/stores/space.ts`、`web/src/components/space/HouseRoomSidebar.vue` 及拆分后的空间树子组件（如 `SpaceTreeNav.vue`）。
- **移动端**：`mobile/lib/core/api_service.dart`、`mobile/lib/screens/space_manage_screen.dart` 及新增模块化组件（如 `house_order_sheet.dart`、`space_manage_cards.dart`），并联动刷新首页 `SpaceAnchorBar`。
- **交互组件合规**：移动端全程使用 `ShadSheet`、`ShadDialog`、`ShadToaster`；Web 端使用自定义 `ConfirmDialog` 与 `ToastContainer`，零原生 `alert()`/`confirm()`/`prompt()`。

