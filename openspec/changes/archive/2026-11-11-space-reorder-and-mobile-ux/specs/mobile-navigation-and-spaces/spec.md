## MODIFIED Requirements

### Requirement: 移动端房屋与房间完整生命周期管理
移动端 SHALL 提供独立的房屋与房间管理页面，采用“顶部房屋横向切换轨 + 下方单层当前房屋房间列表”的扁平布局实现与 Web 端普通成员一致的空间 CRUD 能力，并严守“仅维护至房间层级、不建橱柜实体表”的边界。

#### Scenario: 切换当前管理的房屋与触发操作菜单
- **WHEN** 用户处于房屋与房间管理页面且拥有一个或多个房屋
- **THEN** 页面顶部 SHALL 展示横向可滑动的房屋切换胶囊轨，点击任意房屋胶囊即可在下方单层列表中切换展示该房屋下的房间，不再将多套房屋的房间同时展开在同一个二级垂直列表中
- **WHEN** 用户点击当前房屋摘要栏或任意房间卡片右侧的更多操作按钮
- **THEN** 系统 SHALL 弹出统一样式的 `ShadSheet` 操作菜单提供「查看空间物品」「修改名称与图标」「删除」选项，避免行内多按钮拥挤与误触

#### Scenario: 用户新建、编辑与删除房屋
- **WHEN** 用户在空间管理页面触发新建或通过 `ShadSheet` 菜单触发编辑房屋
- **THEN** 系统 SHALL 弹出统一样式的 `ShadSheet` 表单，提供建筑专属 Emoji 图腾与名称输入，并通过 `POST /api/houses` 或 `PUT /api/houses/{id}` 持久化
- **WHEN** 用户请求删除房屋
- **THEN** 系统 SHALL 弹出危险态 `ShadDialog` 警示将级联清理其下所有房间与物品，仅在用户确认后调用 `DELETE /api/houses/{id}`

#### Scenario: 用户管理房间并支持一键跳转查看物品
- **WHEN** 用户在当前选中房屋下新建或通过 `ShadSheet` 菜单编辑房间
- **THEN** 系统 SHALL 提供房间功能专属 Emoji 图腾并通过 `POST /api/rooms` 或 `PUT /api/rooms/{id}` 保存
- **WHEN** 用户短按某房间卡片或通过房屋/房间操作菜单选择「查看空间物品」
- **THEN** 系统 SHALL 自动返回物品寻宝首页并定位筛选至该房屋或房间

## ADDED Requirements

### Requirement: 移动端房屋与房间长按拖拽排序
移动端 SHALL 支持通过单层长按拖拽手势分别调整房屋之间以及房屋内部房间的展示顺序，并在排序完成后同步刷新首页空间导航顺序。

#### Scenario: 长按拖拽调整当前房屋下的房间顺序
- **WHEN** 用户在房间列表长按任意房间卡片并上下拖拽松手
- **THEN** 系统 SHALL 触发中等强度触觉反馈，乐观更新该房屋内的房间展示顺序，并调用 `PUT /api/rooms/reorder` 携带 `house_id` 与 `ordered_ids` 持久化；若请求失败则回滚顺序并通过 `ShadToaster` 提示错误

#### Scenario: 通过房屋排序抽屉长按拖拽调整房屋顺序
- **WHEN** 用户点击顶部房屋切换轨旁的「调整顺序」按钮（或长按任意房屋胶囊）
- **THEN** 系统 SHALL 弹出仅包含纯房屋列表的 `ShadSheet` 排序抽屉，允许用户长按房屋卡片上下拖拽调整顺序并调用 `PUT /api/houses/reorder` 持久化

#### Scenario: 空间排序变更同步至首页空间栏
- **WHEN** 房屋或房间的排序持久化成功
- **THEN** 物品寻宝首页的房屋选择器与房间胶囊横轨 SHALL 同步按最新 `sort_order` 顺序展示

