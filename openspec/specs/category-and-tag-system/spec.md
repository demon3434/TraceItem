# category-and-tag-system Specification

## Purpose

Defines the comprehensive 14-preset daily category system, user-level category lifecycle management (CRUD and deactivation), and global shared tag autocomplete and idempotent deduplication in TraceItem.

## Requirements

### Requirement: Preset Category Template Seeding on User Creation
The system SHALL provide 14 daily preset categories with Emoji totems, and automatically clone a private copy of this preset template for every newly registered user.

#### Scenario: New user registers and receives default categories
- **WHEN** a new user account is successfully created via the registration API
- **THEN** the system SHALL immediately clone the 14 system preset categories (常备药品 💊, 证件票据 📑, 数码配件 🔌, 五金工具 🧰, 儿童玩具 🧸, 办公文具 ✏️, 厨房用品 🍳, 食品干货 🍵, 日用清洁 🧼, 服饰鞋帽 👔, 美妆个护 💄, 运动户外 ⛺, 家家居家 🛋️, 闲置收藏 📦) into the user's private category records with `is_active=True`.

### Requirement: User Category Lifecycle Management
The system SHALL allow authenticated users to create, update, reorder, and deactivate/activate their private categories, while preventing destructive cascading deletion of items.

#### Scenario: User deactivates a category
- **WHEN** a user sets a category's `is_active` to `False`
- **THEN** existing items associated with this category SHALL continue displaying the category normally, but the deactivated category SHALL be hidden from item creation dropdowns and home screen quick filter tabs.

#### Scenario: User safely deletes a category with items
- **WHEN** a user requests deletion of a category that currently has items attached
- **THEN** the UI SHALL prompt with a custom confirmation dialog (no native confirm) asking whether to unbind associated items (setting `category_id=NULL`) before removing the category, and SHALL NOT delete the items themselves.

### Requirement: Cross-User Tag Sharing and Autocomplete
The system SHALL maintain a global pool of unique tag names without user isolation, enabling cross-user prefix suggestion and autocompletion.

#### Scenario: Autocomplete suggestions for tag input
- **WHEN** a user types a prefix into the tag input field (e.g., "办公")
- **THEN** the frontend SHALL query `GET /api/tags/suggest?q=办公` and display matching existing global tags (e.g., "办公用品") in a custom popover overlay.

### Requirement: Idempotent Tag Resolution on Item Save
The backend SHALL resolve tag names atomically by trimmed case-sensitive exact match, reusing existing tag IDs rather than creating duplicate tag records.

#### Scenario: Saving item with existing tag name avoids duplicates
- **WHEN** an item is submitted with tag name "办公用品" where a tag with that exact trimmed name already exists in the global `tags` table
- **THEN** the backend SHALL link the item to the existing tag record's ID without creating any new row in `tags`.

### Requirement: 移动端与 Web 端分类 Emoji 图标库及分组选择器完全一致
移动端分类管理与 Web 端 MUST 提供完全一致的 **6 大主题分组 × 32 款 = 192 款精选 Emoji 图标库**（包括分组顺序：`🧸 玩具游乐`、`🐾 动物萌宠`、`🍦 零食美味`、`🏠 生活居家`、`🎨 文创装扮`、`⛺ 探索自然`，以及各分组内全部 Emoji 排列顺序），并在新建分类与编辑分类入口采用统一的触发按钮与底部抽屉分组选择器。

#### Scenario: 用户在移动端新建分类时打开分组图标选择器
- **WHEN** 用户在移动端物品分类管理页的新建区域点击输入框左侧的当前图标按钮（默认显示 `📦`）
- **THEN** 系统 SHALL 弹出底部 `ShadSheet` 图标选择器抽屉，展示 Web 端同步的 6 大主题分组标签与当前选中分组的 32 款图标网格，并在底部显示当前已选图标提示。

#### Scenario: 用户切换分组并选定新图标用于新建或编辑分类
- **WHEN** 用户在图标选择器抽屉中切换任意主题分组（如从「玩具游乐」切换至「探索自然」），并点击某一款 Emoji 图标
- **THEN** 系统 SHALL 高亮当前选定图标、附带轻量触觉反馈并立即关闭抽屉，同时将该图标回填至新建栏或编辑分类抽屉的图标按钮中等待提交保存。

#### Scenario: 用户在移动端编辑已有分类时修改图标
- **WHEN** 用户点击已有分类卡片的编辑按钮打开「修改物品分类」抽屉，并点击抽屉内输入框左侧的当前分类图标按钮
- **THEN** 系统 SHALL 打开同一套 `ShadSheet` 分组图标选择器并默认高亮该分类当前使用的图标；用户选定新图标并点击「保存修改」后，分类列表 SHALL 立即更新为新图标。

### Requirement: 移动端分类管理列表卡片防挤压与安全排版规范
移动端（Flutter）分类管理列表项卡片 SHALL 遵循防挤压排版规范：分类名称与副标题说明必须显式限制为单行并设置溢出省略保护（`TextOverflow.ellipsis`），严禁在水平 `Row` 中平铺超过 1 个独立操作图标按钮，右侧仅允许展示轻量状态胶囊 Badge 与单枚统一的 `...` 更多操作按钮。

#### Scenario: 窄屏移动设备下的分类文本自适应渲染
- **WHEN** 用户在窄屏（如 360dp 逻辑宽度）移动设备上打开分类管理页面
- **THEN** 系统 SHALL 保证分类名称与启用状态文字水平横向舒展展示，绝不发生逐字折行塌陷成单字竖排，且文本超出时优雅显示为省略号。

### Requirement: 移动端分类管理统一操作抽屉 (CategoryActionSheet)
系统 SHALL 为移动端分类管理提供基于温润大圆角半屏抽屉（`ShadSheet`）的统一操作菜单。点击卡片右侧 `...` 按钮时唤起抽屉，提供修改名称与图标、切换启用/停用状态、解绑删除等操作选项，提供舒适宽裕的触控热区并消除误触风险。

#### Scenario: 唤起分类操作抽屉并修改分类
- **WHEN** 用户在分类卡片右侧点击 `...` 操作按钮
- **THEN** 系统 SHALL 从屏幕底部滑出 `CategoryActionSheet` 半屏抽屉，展示该分类的图标、名称与操作选项列表；用户点击“修改名称与图标”后 SHALL 打开编辑分类弹窗。

#### Scenario: 抽屉内安全解绑删除分类
- **WHEN** 用户在 `CategoryActionSheet` 中点击高亮红色的“解绑并删除分类”选项
- **THEN** 系统 SHALL 先关闭操作抽屉，并弹出统一确认对话框（`CustomDialogs.showConfirm`），明确告知“仅清空分类关联，不删除物品实体”；用户确认后系统执行安全删除并刷新列表。

### Requirement: 移动端分类原生拖拽重新排序
移动端分类管理页面 SHALL 支持直观的原生拖拽重新排序交互，废弃卡片内上下箭头按钮，用户通过长按或拖拽把手即可实时调整分类显示先后次序，并在松手后自动同步保存至后端。

#### Scenario: 拖拽分类调整次序并自动持久化
- **WHEN** 用户长按某个分类卡片并拖动调整到新位置后松开
- **THEN** 系统 SHALL 触发轻微触觉反馈（`HapticFeedback.lightImpact`），即时更新本地列表顺序，并自动提交后端更新该分类及相关分类的排序序号（`sort_order`）。

### Requirement: 移动端表单抽屉软键盘唤起自适应与防截断规范
移动端所有包含文本输入的半屏抽屉（如房屋创建/编辑、房间创建/编辑、分类编辑等 `ShadSheet`）SHALL 具备优雅的软键盘自适应伸展机制：开启自适应高度控制（`isScrollControlled: true`），严禁在抽屉内部冗余叠加多重 `viewInsets.bottom`，确保输入法弹出时光标所在文本框完整的上下左右四周边框均无视口裁剪地展示在可视窗口内。

#### Scenario: 弹出输入法时输入框四周边框完整展现
- **WHEN** 用户在房屋/房间/分类等抽屉表单中点击文本输入框聚焦并弹出输入法软键盘
- **THEN** 系统 SHALL 自适应抬高并伸展抽屉视口，文本框及其四周高亮聚焦边框 SHALL 100% 完整呈现在视口内部，绝不发生下半截被视口裁剪导致的左右边框与底边框截断现象。
