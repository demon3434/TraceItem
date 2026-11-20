# Design

## Context

当前 `House` 与 `Room` 仅存在 `is_deleted` 软删除字段（`server/app/models/space.py`），删除接口（`delete_user_house`、`delete_user_room`）会无条件将下属房间及物品批量置为 `is_deleted = True`。同时，项目中 `Category` 已成功落地 `is_active` 启停模式（含 `PATCH /items/categories/{id}/status`、录入过滤及编辑保留当前选中项逻辑），可作为本次空间治理设计的一致性参照。

## Goals / Non-Goals

**Goals:**
- 在后端服务层建立严格的删除非空拦截：存在未删除物品的房屋或房间一律禁止删除，空房屋允许连带删除其名下空房间。
- 为 `House` 与 `Room` 引入 `is_active` 启停能力，保证历史物品可查、日常录入不干扰、房屋与房间状态独立且继承生效。
- 在 Web 与 Mobile 端提供符合设计规范的启停操作、删除拦截引导、录入过滤与「显示已停用空间」开关。
- 严格遵守单文件代码 <500 行、全端统一自定义弹窗（零原生 `alert`/`confirm`）以及 Mobile ARMv8 Release 约束。

**Non-Goals:**
- 本次不实现“一键批量迁移房间内全部物品到另一房间”的独立向导（用户可通过编辑单个物品调整位置，或直接停用空间）。
- 本次不修改 Admin 上帝视角（跨用户紧急寻物）的可见范围——Admin 依然可检索到所有未删除物品，无论其所在空间是否停用。

## Decisions

### 1. 删除拦截判定与错误响应
- **房间删除 (`delete_user_room`)**：统计 `Item.room_id == room_id` 且 `Item.is_deleted == False` 的记录数。若计数 `> 0`，抛出 `HTTP 400`（`detail="该房间内还有 {count} 件物品，无法直接删除；请先迁移/删除物品，或改为停用该房间"`）。
- **房屋删除 (`delete_user_house`)**：统计 `Item.house_id == house_id` 且 `Item.is_deleted == False` 的记录数。若计数 `> 0`，抛出 `HTTP 400`（`detail="该房屋内还有 {count} 件物品，无法直接删除；请先清理物品，或改为停用该房屋"`）；若计数 `== 0`，允许软删除房屋并连带将名下空房间设为 `is_deleted = True`。
- **理由**：以物品作为唯一强保护资产，空房间不构成资产损失风险，避免用户删除废弃空房屋前还要逐个点删十几个空房间。

### 2. `is_active` 状态存储与继承规则
- **数据模型与迁移**：在 `House` 和 `Room` 表新增 `is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)`，并在 `init_db.py` 中对既有表执行 `ALTER TABLE ... ADD COLUMN is_active BOOLEAN DEFAULT 1;` 兼容迁移。
- **接口设计**：
  - `HouseOut` / `RoomOut` 返回 `is_active: bool`。
  - `HouseUpdate` / `RoomUpdate` 支持可选 `is_active: Optional[bool]`，并新增语义清晰的 `PATCH /api/houses/{house_id}/status` 与 `PATCH /api/rooms/{room_id}/status`（参考分类状态切换接口风格，支持 `is_active` 参数）。
- **继承判定（不覆盖子状态）**：
  - 停用房屋时**不修改**下属房间的 `Room.is_active` 字段。
  - 前端判断房间是否可录入时使用 `house.is_active && room.is_active`。
  - 后端 `create_user_room` 校验所属 `house.is_active == True`；`create_user_item` 校验 `house.is_active == True`、`room.is_active == True` 且二者均 `is_deleted == False`。
  - `update_user_item` 仅当 `house_id` 或 `room_id` 发生变更时，要求目标房屋与房间均处于启用且未删除状态；若未变更位置，允许在原停用空间内保存其他字段修改。

### 3. 前端交互与组件拆分（严控单文件 <500 行）
- **Web 端**：
  - `HouseRoomSidebar.vue` / `SpaceTreeNav.vue` 顶部或操作区新增「显示已停用空间」轻量开关（默认关闭）；树节点悬停/更多操作中增加「停用/启用」按钮，已停用节点以柔和置灰 + `已停用` 徽章展示。
  - `MainView.vue` 删除房屋/房间时，若后端返回非空拦截错误，通过自定义 Toast/ConfirmDialog 提示，严禁调用原生 `confirm()`/`alert()`。
  - `ItemDialog.vue` 新建时过滤 `house.is_active && room.is_active`；编辑时保留 `id == currentId` 的已停用空间。
- **移动端**：
  - 遵循 `mobile-ui-craftsmanship` 与“单行最多 1 个操作按钮”红线：空间管理页（`space_manage_screen.dart`）通过 `...` 按钮打开 `SpaceActionSheet`（`ShadSheet`），在抽屉内提供「停用/启用」与「删除」大热区选项；`space_manage_cards.dart` 展示柔和的「已停用」药丸徽章。
  - 首页空间筛选弹窗（`home_filter_sheets.dart`）增加「显示已停用空间」开关（默认关闭）。
  - `item_edit_pickers.dart` 与 `item_edit_screen.dart` 在新建时仅列出有效启用空间，编辑时保留当前所在已停用空间。

## Risks / Trade-offs

- **风险**：如果用户在移动端或 Web 端关闭了「显示已停用空间」开关，可能会一时忘记自己停用过某个老房屋而误以为数据丢失。
  - **缓解**：全局搜索（FTS5）不受空间 `is_active` 限制，依然能搜出所有旧物；同时在空间筛选器与侧边栏明确提供「显示已停用空间」切换开关及停用数量提示。
- **风险**：在 `space_manage_screen.dart`、`MainView.vue` 或 `ItemDialog.vue` 中直接堆积新逻辑可能导致单文件接近或超过 500 行。
  - **缓解**：将状态切换与确认/引导逻辑下沉至独立辅助组件或 composable/helper，提交前统一检查所有改动文件行数 `< 500`。

