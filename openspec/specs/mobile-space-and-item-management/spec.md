# mobile-space-and-item-management Specification

## Purpose

Enables in-app space entity management (rooms and emoji totems), full item editing and updating workflows, network host configuration, and strict kid-friendly typography standards on mobile devices.

## Requirements

### Requirement: Mobile Space Entity Management Sheet
The mobile application SHALL provide a bottom sheet (`ShadSheet`) allowing users to create and edit room entities with customizable Emoji totems.

#### Scenario: User creates a new room
- **WHEN** a user opens the space management sheet, inputs a room name, selects an Emoji totem (e.g., 🧸, 🚀, 🛋️), and submits
- **THEN** the app SHALL persist the new room under the active house via `POST /api/rooms` and refresh the horizontal room chip selector.

### Requirement: Item Editing and Updating Workflow
The mobile application SHALL allow users to modify existing item attributes, update physical locations, and manage attachments.

#### Scenario: User enters edit mode for existing item
- **WHEN** a user taps "Edit" on an item details card or preview dialog
- **THEN** the app SHALL open `ItemEditScreen` populated with existing name, brand, quantity, location detail, tags, and attachments, submitting updates via `PUT /api/items/{id}` upon save.

### Requirement: Dynamic Server Connection Configuration
The mobile application SHALL allow users to configure and verify the backend API host without rebuilding the app package.

#### Scenario: User changes server base URL
- **WHEN** a user opens connection settings and enters a custom server host (e.g., LAN IP or DDNS domain)
- **THEN** the app SHALL perform a connectivity handshake test against `/api/health`, and persist the validated URL to local preferences upon success.

### Requirement: Mobile Typography and Readability Standards
The mobile application SHALL strictly enforce readable font sizes across all screens and widgets to ensure comfortable usage for children and elderly family members.

#### Scenario: Rendering text on mobile screens
- **WHEN** any text element is rendered in item cards, lists, dialogs, or inputs
- **THEN** font size SHALL NOT be smaller than 12px, with standard body and input text sized between 14px and 16px, completely eliminating sub-12px micro-text.

### Requirement: 移动端已取出物品极简图标角标
移动端物品卡片在物品处于 `in_use` 状态时 SHALL 仅通过紧凑的纯 Lucide 图标微徽章标识已取出状态，不在卡片上渲染“使用中”汉字文本或额外的“已用完”标签。

#### Scenario: 渲染已取出物品卡片
- **WHEN** 移动端物品列表或搜索结果渲染 `status` 为 `in_use` 的物品卡片
- **THEN** 卡片封面或标题角落 SHALL 显示紧凑的 Lucide `PackageOpen` 图标角标以提示已取出，不得渲染“使用中”文字标签，且封面优先展示 `in_use` 组图片

#### Scenario: 渲染数量为 0 的物品卡片
- **WHEN** 移动端物品卡片渲染 `quantity` 为 `0` 的物品
- **THEN** 卡片 SHALL 仅按常规格式显示数量 `0`，不得额外增加状态标签

### Requirement: 移动端取出使用登记页与独立归还页面
移动端 SHALL 提供全屏的取出使用登记页与独立归还收纳页面（而非底部抽屉），并在详情页底栏按“数量调整 -> 编辑 -> 取出/归还（方案 A 纯图标） -> 删除”顺序排列；全部确认与提示 SHALL 使用 `ShadDialog` 与 `CustomDialogs.showToast`，严禁调用系统原生弹窗。

#### Scenario: 打开取出使用登记表单
- **WHEN** 用户在物品详情页底栏点击纯图标「取出使用」按钮
- **THEN** 移动端 SHALL 打开取出登记全屏页，物品名称、品牌、分类、标签与数量以只读状态带入且不可修改，当前房屋/房间与位置备注允许编辑，附件区域清空并要求至少提交 1 张新照片后方可保存

#### Scenario: 通过独立全屏页面执行归还收纳
- **WHEN** 用户对 `in_use` 物品点击纯图标「归还收纳」按钮
- **THEN** 移动端 SHALL 打开独立全屏归还页提供“原位放回”与“更换位置/替换照片”选项；确认归还后同步清理使用中附件并刷新为收纳态

### Requirement: 移动端消耗品快捷步进与归零二次确认
移动端 SHALL 在物品详情页提供快捷 `-1 / +1` 数量步进控件，并在数量减至 `0` 时通过两步 `ShadDialog` 确认是否删除。

#### Scenario: 数量减至 0 时的二次确认弹窗流
- **WHEN** 用户点击快捷减一按钮使物品数量由 `1` 变为 `0`
- **THEN** 移动端 SHALL 连续弹出两次 `ShadDialog` 确认框；仅当用户两次均确认删除时才调用删除接口，任一步取消或选择保留则将数量更新为 `0`
