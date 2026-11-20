# web-space-management Specification

## Purpose
Defines the full lifecycle management of spatial hierarchy (Houses and Rooms) on the Web frontend, including creation, modification of names and Emoji totems, and cascade deletion with safe confirmation dialogs.

## Requirements

### Requirement: House and Room Renaming and Icon Update
The web application SHALL allow users to modify the name, Emoji totem icon, and sort order of any existing house or functional room.

#### Scenario: Editing an existing house
- **WHEN** a user triggers the edit action on a house node in the sidebar
- **THEN** the system SHALL display the house edit modal populated with current values, and upon saving, invoke `PUT /api/houses/{id}` and refresh the spatial sidebar

#### Scenario: Editing an existing room
- **WHEN** a user triggers the edit action on a room node under a house
- **THEN** the system SHALL display the room edit modal with pre-selected room functional totems, and upon saving, invoke `PUT /api/rooms/{id}` and refresh the spatial list

### Requirement: Spatial Cascade Deletion with Danger Confirmation
Web 端 SHALL 通过自定义 `ConfirmDialog` 进行删除前危险确认，并在房屋或房间内存在未删除物品时禁止删除且引导改为停用，严禁使用浏览器原生 `alert()`、`confirm()` 或 `prompt()`。

#### Scenario: Deleting a house invokes confirmation dialog
- **WHEN** 用户点击删除无任何物品的空房屋或空房间
- **THEN** 系统 SHALL 不得使用浏览器原生 `confirm()`，而 MUST 打开自定义 `ConfirmDialog` 进行危险确认，并在确认后调用 `DELETE /api/houses/{id}` 或 `DELETE /api/rooms/{id}` 完成删除

#### Scenario: 删除非空房屋或房间时拦截并引导停用
- **WHEN** 用户点击删除某房屋或房间，且其名下存在未删除物品（服务端返回拦截错误或前端已知存在物品）
- **THEN** 系统 SHALL 不得使用浏览器原生弹窗，而 MUST 通过自定义 `ConfirmDialog` 或自定义 Toast 明确提示不可删除的原因（含物品数量引导），并提供「停用」替代建议

### Requirement: Web 端空间侧边栏显式排序模式与作用域隔离
Web 端 SHALL 在左侧空间管理侧边栏提供显式的「排序模式」，允许用户通过拖拽或上下微调按钮调整房屋先后顺序以及同一房屋内部房间的先后顺序，并严格禁止房间跨房屋拖放。

#### Scenario: 切换至空间排序模式
- **WHEN** 普通成员点击左侧空间栏「我的空间层级」旁的「排序」按钮
- **THEN** 侧边栏 SHALL 进入排序模式，按钮切换为「完成」，隐藏原有的悬停增删改浮层，并在房屋行与当前展开房屋下的房间行展示拖拽手柄与上/下微调按钮

#### Scenario: 调整房屋顺序并严格隔离拖拽作用域
- **WHEN** 用户在排序模式下拖拽房屋节点到另一房屋节点位置，或点击房屋行的上/下微调按钮
- **THEN** 系统 SHALL 立即更新房屋列表顺序并调用 `PUT /api/houses/reorder` 持久化，操作反馈使用自定义 Toast，严禁使用浏览器原生弹窗

#### Scenario: 调整房屋内部房间顺序且禁止跨房屋拖放
- **WHEN** 用户在排序模式下拖拽某房屋下的房间节点到同房屋的另一房间位置，或点击房间行的上/下微调按钮
- **THEN** 系统 SHALL 立即更新该房屋下的房间顺序并调用 `PUT /api/rooms/reorder` 持久化；若将房间拖拽至房屋行或其他房屋作用域则不产生放置效果

#### Scenario: 批量重排接口校验与新建默认追加顺序
- **WHEN** 客户端调用 `PUT /api/houses/reorder` 或 `PUT /api/rooms/reorder`
- **THEN** 服务端 SHALL 校验所有传入 ID 均属于当前登录用户（且房间均属于指定 `house_id`）且未软删除，并在同一事务中按传入序列重置 `sort_order`
- **WHEN** 用户未指定有效正序值而新建房屋或房间
- **THEN** 服务端 SHALL 自动赋予其当前同作用域内最大 `sort_order + 1`，使其默认排在列表末尾

### Requirement: Web 端房屋与房间启停控制及已停用空间开关
Web 端 SHALL 支持在空间管理侧边栏启停房屋与房间，默认隐藏已停用空间并提供显式切换开关以便随时找回历史物品，同时在物品录入表单中隐藏已停用空间。

#### Scenario: 切换房屋或房间的启用与停用状态
- **WHEN** 用户在左侧空间栏对房屋或房间执行「停用」或「启用」操作
- **THEN** Web 端 SHALL 调用对应的状态更新接口并更新本地空间状态，停用成功提示使用自定义 Toast

#### Scenario: 空间侧边栏「显示已停用空间」开关
- **WHEN** 用户在左侧空间栏查看空间列表（默认开关关闭）
- **THEN** 系统 SHALL 默认收起或隐藏已停用的房屋与房间；当用户开启「显示已停用空间」开关后，SHALL 展示已停用空间并附带清晰的「已停用」视觉标识，点击仍可筛选查看其中的历史物品

#### Scenario: 物品录入与编辑表单中的空间选项过滤
- **WHEN** 用户打开新建物品弹窗
- **THEN** 房屋与房间下拉选择器 SHALL 仅展示 `is_active == True` 的有效启用空间
- **WHEN** 用户打开编辑历史物品弹窗且该物品当前归属的空间已被停用
- **THEN** 选择器 SHALL 保留当前所属空间选项以便编辑其他信息，同时隐藏其他已停用空间
