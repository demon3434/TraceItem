## Context

当前项目的空间模型（`server/app/models/space.py`）已在 `House` 和 `Room` 表定义了 `sort_order` 字段，查询接口（`server/app/services/space_service.py`）也已按 `sort_order.asc(), id.asc()` 返回结果，但前后端均缺少针对房屋和房间的批量重排链路，且 Web 端新建时默认 `sort_order=0` 会导致多条记录序号冲突。

同时，移动端「房屋和房间」页面（`mobile/lib/screens/space_manage_screen.dart`）目前将所有房屋与房间折叠嵌套在同一个 `ListView` 中，每行放置多个图标按钮；Web 端（`web/src/components/space/HouseRoomSidebar.vue`）宽度较窄且点击节点承担筛选跳转职责，需要避免常规浏览态下的误拖拽。

## Goals / Non-Goals

**Goals:**
- 提供原子化、幂等的房屋与房间批量重排 API（`PUT /api/houses/reorder`、`PUT /api/rooms/reorder`），并修正新建房屋/房间的默认 `sort_order` 分配策略。
- 将移动端空间管理页面重构为“顶部房屋横向胶囊轨 + 单层房间长按拖拽列表 + 房屋排序 `ShadSheet` + 卡片 `ShadSheet` 操作菜单”，彻底消除二级嵌套拖拽冲突与多房屋页面冗长问题。
- 为 Web 端左侧空间侧边栏引入显式「排序模式」，同时支持拖拽手柄与 `↑/↓` 按钮微调，并严格隔离房屋与房间（按 `house_id`）的拖放作用域。
- 严格遵守单文件 `< 500` 行约束，对接近上限的移动端与 Web 端空间组件进行模块化拆分。

**Non-Goals:**
- 不支持将房间通过拖拽跨房屋移动归属（修改房间所属房屋仍通过编辑弹窗/抽屉完成）。
- 不新增橱柜、抽屉等三级以下数据库实体，严守 `House -> Room` 两级物理空间模型。
- 不改变管理员视角（Admin 账号禁止拥有私有房屋/房间，侧边栏为管理工作台）。

## Decisions

### 1. 后端批量重排 API 契约与默认排序策略
- **决策**：参照已有 `PUT /api/admin/category-templates/reorder` 的模式，新增：
  - `PUT /api/houses/reorder`：请求体 `{ ordered_ids: List[int] }`，返回 `List[HouseOut]`。
  - `PUT /api/rooms/reorder`：请求体 `{ house_id: int, ordered_ids: List[int] }`，返回 `List[RoomOut]`（该房屋下更新后的房间列表）。
- **校验与更新规则**：
  - 查询当前用户名下（以及房间场景下 `Room.house_id == payload.house_id`）全部未软删除记录。
  - 校验 `ordered_ids` 无重复且与当前有效记录 ID 集合完全一致（或全部包含于有效集合，若存在非法/跨用户/跨房屋 ID 返回 400），按列表索引从 `1` 开始顺序写入 `sort_order`，单次 `db.commit()` 原子落库。
  - **新建默认顺序**：在 `create_user_house` 与 `create_user_room` 中，当客户端未传入大于 0 的 `sort_order`（如 `payload.sort_order <= 0`）时，自动查询同作用域最大 `sort_order` 并赋值为 `max_order + 1`，彻底解决旧版全为 `0` 导致排序错乱的问题。
- **替代方案**：前端在拖拽后循环调用 N 次 `PUT /api/houses/{id}` 或 `PUT /api/rooms/{id}`。**否定原因**：并发多请求易产生竞争状态与部分成功不一致，且网络往返次数多。

### 2. 移动端「房屋和房间」单层扁平重构（方案 A）
- **决策**：将 `SpaceManageScreen`（当前 422 行）拆分为协调页面与独立子组件（`house_order_sheet.dart`、`space_manage_cards.dart`），主页面采用三段式扁平结构：
  1. **顶部房屋横向胶囊轨**：可横向滚动切换当前管理的房屋，右端固定「调整顺序」按钮；支持点击切换房屋，也支持长按任意房屋胶囊直接唤起房屋排序 `ShadSheet`。
  2. **当前房屋摘要条**：展示当前选中房屋图标、名称、房间数量与 `...` 操作菜单触发器（查看房屋物品 / 新建房间 / 编辑房屋 / 删除房屋）。
  3. **单层房间 `ReorderableListView`**：仅渲染当前选中房屋下的房间卡片，使用 `ReorderableDelayedDragStartListener` 包裹卡片实现长按任意位置拖拽（开始拖拽触发 `HapticFeedback.mediumImpact()`），卡片右侧仅保留 `GripVertical` 拖拽提示与 `...` 菜单按钮。
- **房屋排序入口**：点击「调整顺序」弹出 `ShadSheet`（`HouseOrderSheet`），内含纯房屋单层 `ReorderableListView`，无任何房间嵌套，5~10 个房屋亦可在半屏内顺畅长按拖拽重排。
- **替代方案**：二级页面钻取（第一页纯房屋列表，点击推入第二页纯房间列表）。**权衡**：方案 A 在家庭常见 2~4 套房屋场景下切换调整各屋房间只需单指点按顶部胶囊 1 次，无需反复入栈返回；同时借助 `HouseOrderSheet` 解决了多房屋时页面冗长和嵌套拖拽冲突。

### 3. Web 端侧边栏显式「排序模式」与模块拆分
- **决策**：在 `HouseRoomSidebar.vue`（当前 435 行）中将普通成员空间树抽离为 `SpaceTreeNav.vue`（保证每文件均控制在 300~400 行内）：
  - 在「我的空间层级」标题行新增 `排序 / 完成` 切换按钮（使用 `ArrowUpDown` / `Check` Lucide 图标）。
  - 非排序态保持现有点击筛选 + 悬停 `[+ | 编辑 | 删除]` 体验；进入排序态后隐藏悬停增删改浮层，展示左侧 `GripVertical` 与右侧 `↑ / ↓` 微调按钮。
  - **严格作用域隔离**：在拖拽状态中记录 `{ kind: 'house' | 'room', id: number, houseId?: number }`，房屋行仅接受 `kind === 'house'` 的落点，房间行仅接受 `kind === 'room' && drag.houseId === targetRoom.house_id` 的落点；跨房屋或跨层级拖放直接忽略。
  - **持久化时机**：每次落位或点击 `↑ / ↓` 即乐观更新 `spaceStore.houses` / `spaceStore.rooms` 并异步调用对应 `reorder` API，失败时恢复快照并触发 `toastStore.error`。

## Risks / Trade-offs

- **[数据迁移风险] 历史数据中存在多个 `sort_order = 0` 的房屋或房间** → 首次调用 `/reorder` 时会直接用 `1..N` 覆写全部记录的 `sort_order`，天然自愈；排序前查询仍以 `(sort_order ASC, id ASC)` 保证确定性。
- **[手势冲突风险] 移动端房间卡片既支持短按查看物品、长按拖拽，又需兼容空状态与少房间时的下拉刷新** → 短按与 `ReorderableDelayedDragStartListener` 的长按在 Flutter 手势竞技场天然互斥，不会误触；将 `...` 菜单置于独立 `IconButton` 上避免点击菜单触发拖拽；保留 `RefreshIndicator` 并在拖拽进行中禁用额外冲突动画。
- **[文件行数超限风险] `SpaceManageScreen`（422 行）和 `HouseRoomSidebar.vue`（435 行）已接近 500 行** → 通过拆出 `house_order_sheet.dart`、`space_manage_cards.dart` 和 `SpaceTreeNav.vue`，在规划阶段强制把单文件体积压到 350 行以下。

