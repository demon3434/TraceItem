## 1. 服务端空间批量排序接口与默认序号修正

- [x] 1.1 在 `server/app/schemas/space.py` 新增 `HouseReorderPayload`（`ordered_ids: List[int]`）与 `RoomReorderPayload`（`house_id: int`、`ordered_ids: List[int]`），在 `server/app/services/space_service.py` 实现 `reorder_user_houses` 与 `reorder_user_rooms`（校验用户归属、房屋归属、无重复与全量集合匹配并单事务更新 `sort_order`），并修正 `create_user_house` / `create_user_room` 在默认 `sort_order <= 0` 时自动取同作用域最大 `sort_order + 1`，通过端到端测试验证持久化结果
- [x] 1.2 在 `server/app/api/houses.py` 新增 `PUT /api/houses/reorder` 路由、在 `server/app/api/rooms.py` 新增 `PUT /api/rooms/reorder` 路由，并在 `server/tests/test_api_e2e.py` 补充房屋重排、同房屋房间重排、跨用户/跨房屋非法 ID 拦截（400）及新建追加末尾顺序测试，运行 `pytest` 全部通过

## 2. Web 端空间侧边栏显式排序模式与模块化拆分

- [x] 2.1 在 `web/src/api/index.ts` 新增 `reorderHousesApi` 与 `reorderRoomsApi`，并在 `web/src/stores/space.ts` 新增 `reorderHouses` 与 `reorderRooms` 状态方法（支持乐观更新与异常回滚），验证类型检查无报错
- [x] 2.2 将 `web/src/components/space/HouseRoomSidebar.vue` 中的普通成员空间导航树拆分为独立子组件 `web/src/components/space/SpaceTreeNav.vue`（确保两个文件均严格控制在 400 行以内），在「我的空间层级」标题栏新增 `排序 / 完成` 切换按钮，采用 Lucide `ArrowUpDown`、`Check`、`GripVertical`、`ArrowUp`、`ArrowDown` 图标与多巴胺主题 CSS 变量令牌，严禁任何原生 `alert`/`confirm`/`prompt`
- [x] 2.3 在 `SpaceTreeNav.vue` 实现排序模式下的 HTML5 拖拽与上下微调交互，严格隔离拖拽作用域（房屋仅在房屋层重排、房间仅在同 `house_id` 下重排），每次落位或微调即时持久化并使用 `toastStore` 反馈，运行 `npm run build` 验证构建通过

## 3. 移动端「房屋和房间」扁平重构与长按拖拽排序

- [x] 3.1 在 `mobile/lib/core/api_service.dart` 新增 `reorderHouses(List<int> orderedIds)` 与 `reorderRooms(int houseId, List<int> orderedIds)` 方法，验证静态分析无报错
- [x] 3.2 拆分创建 `mobile/lib/widgets/space_manage_cards.dart` 与 `mobile/lib/widgets/house_order_sheet.dart`：封装顶部房屋横向切换胶囊轨（含长按触发排序入口与「调整顺序」按钮）、当前房屋摘要条、房间拖拽卡片（22px 圆角与 `ambientShadows`、字号 >= 12px）、统一 `ShadSheet` 操作菜单（查看空间物品/编辑/删除，危险删除沿用 `ShadDialog`）及纯房屋单层 `ReorderableListView` 排序抽屉（`ShadSheet`），确保各文件均低于 350 行
- [x] 3.3 重构 `mobile/lib/screens/space_manage_screen.dart` 为「顶部房屋切换轨 + 单层房间 `ReorderableListView`」，使用 `ReorderableDelayedDragStartListener` 实现长按整卡拖拽与 `HapticFeedback.mediumImpact()` 触觉反馈，乐观更新顺序并调用批量重排接口持久化（失败回滚并以 `ShadToaster` 提示），同步触发 `onDataUpdated` 刷新首页 `SpaceAnchorBar`

## 4. 全端校验与规范检查

- [x] 4.1 核查本次全部新增与修改源码文件的行数均严格 `< 500` 行、无任何浏览器原生弹窗调用、图标统一使用 Lucide Icons，并运行服务端 `pytest`、Web 端 `npm run build` 与移动端 `flutter analyze` 验证通过

