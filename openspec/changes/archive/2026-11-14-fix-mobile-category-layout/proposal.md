# Proposal

## Why

在手机实测中，移动端（Flutter）发现了两类破坏用户体验与界面的严重显示缺陷：
1. **分类管理卡片行内挤压与单字竖排**：单行卡片内横排 5 个 48dp `IconButton` 霸占 240dp 宽度，导致 360dp 窄屏手机上的 `Expanded` 仅剩 24dp，触发文字逐字折行塌陷成垂直单字瀑布，且触控极易误触；
2. **底部表单抽屉软键盘唤起时视口截断与边框消失**：在房屋空间、功能房间以及分类修改等半屏抽屉（`ShadSheet`）中，当弹出输入法输入文字时，由于三重重复添加 `viewInsets.bottom` 避让、抽屉未声明 `isScrollControlled: true`（导致最大高度被死死锁死在 9/16）、以及底部操作栏固定钉死（`actionsPinned: true`）占用高度，导致中间可滚动视口（Viewport）被严重压缩至仅剩 40~50dp，输入框下半截被 Viewport 底部边界直接裁剪（Clip），导致聚焦状态下的蓝色边框仅显示顶边和两角，左右边框和底边框消失露出底板白，产生“文本框左右边框被白色遮住了一部分”的严重显示缺陷。

为了彻底消除这两类缺陷并建立长效防范机制，本提案全面重构分类列表与移动端所有半屏表单抽屉的布局、键盘避让与视口适应逻辑。

## What Changes

- **重构分类列表卡片布局**：移除行内平铺的 5 个 `IconButton`；增加状态胶囊 Badge（`启用` / `停用`）与单枚统一的 `...` 更多操作按钮；分类名称与描述文本添加单行截断与省略保护。
- **引入分类统一操作抽屉 (`CategoryActionSheet`)**：基于 `ShadSheet` 提供温润大热区操作选项，彻底杜绝误触。
- **升级分类拖拽重排交互**：采用 `ReorderableListView.builder` 原生物理长按拖拽重排。
- **彻底根治表单抽屉键盘避让与视口截断**：
  - 清理 `HouseRoomFormSheet`、分类编辑等抽屉内部重复叠加的 `MediaQuery.viewInsets.bottom`；
  - 抽屉统一开启 `isScrollControlled: true`，在软键盘弹起时自适应向上展开至充足高度；
  - 操作按钮栏改为紧凑水平排列（`actionsAxis: Axis.horizontal`）并解除过度挤压，确保输入框四周边框 100% 完整展示。
- **固化移动端防挤压与键盘避让硬性红线**：在 `AGENTS.md` 全局规范中写入防挤压与表单抽屉键盘避让规范。

## Capabilities

### New Capabilities

无（沿用现有能力）。

### Modified Capabilities

- `category-and-tag-system`: 明确移动端分类管理卡片防挤压、统一操作抽屉、拖拽排序，以及移动端表单抽屉（`ShadSheet`）在唤起软键盘时的自适应展开与防截断规范。

## Impact

- **受影响代码**：
  - `mobile/lib/screens/category_manage_screen.dart`：卡片防挤压、拖拽排序、修改分类抽屉键盘避让与水平按钮栏。
  - `mobile/lib/widgets/category_action_sheet.dart`：新建独立分类操作抽屉。
  - `mobile/lib/widgets/house_room_form_sheet.dart`：根治房屋/房间表单抽屉键盘弹出时的视口截断与边框消失问题。
  - `AGENTS.md`：沉淀防挤压与软键盘抽屉避让规范。
- **API & 数据库影响**：零破坏，完全兼容现有数据结构与前后端交互。
