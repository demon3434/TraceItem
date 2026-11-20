# Design

## Context

在 TraceItem 移动端中，除了分类列表的行内按钮挤压问题外，实测还暴露了半屏抽屉表单在软键盘弹起时的视口严重截断缺陷：
当用户在“新建房屋空间”等表单抽屉中点击输入框时，聚焦状态下的输入框四周本应有一圈蓝色高亮边框，但因视口高度被挤压到极小极限，导致输入框下半截被 `SingleChildScrollView` 的 Viewport 底部边界直接裁剪（Clip），左右两侧边框在中间截断，露出下方的白色底板，使得用户视觉上产生“输入框左右边框被白色遮挡住了一部分”的怪异 Bug。

此缺陷由三重复合原因导致：
1. `showShadSheet` 外部已经具备基于 `AnimatedPadding(bottom: viewInsets.bottom)` 的键盘顶起机制，但抽屉内部代码又手动叠加了 `bottom: MediaQuery.of(context).viewInsets.bottom + 8`，造成双重/三重空白高度堆叠；
2. `ShadSheet` 默认 `isScrollControlled: false`，其最大高度被写死在屏幕的 `9 / 16`（约 56%），无法在键盘升起时灵活向上伸展空间；
3. `actionsPinned: true` 且操作按钮默认全宽竖向堆叠，在抽屉底部占去近 100dp 的死区空间，将可滚动视口压榨到仅剩数十像素。

## Goals / Non-Goals

**Goals:**
- **消除行内密集按钮**：将卡片行内 5 个 `IconButton` 彻底清空，右侧统一替换为状态药丸 Badge + 单枚 `...` 更多操作按钮；
- **全防护排版**：对分类名称及状态描述严格配置 `maxLines: 1` 与 `overflow: TextOverflow.ellipsis`；
- **抽取操作抽屉组件**：在 `mobile/lib/widgets/category_action_sheet.dart` 中实现专属 `CategoryActionMenuSheet`；
- **原生拖拽排序**：将列表改造为 `ReorderableListView.builder`，提供直观平滑的拖拽排序；
- **彻底根治抽屉键盘截断缺陷**：
  - 清理 `house_room_form_sheet.dart`、`category_manage_screen.dart` 等所有抽屉内部多余的 `viewInsets.bottom`；
  - 抽屉配置 `isScrollControlled: true`，支持随输入法自适应伸展视口；
  - 操作栏按钮改为紧凑横排（`actionsAxis: Axis.horizontal`），为视口留出充足垂直空间，保证输入框四周边框 100% 完整展示；
- **固化制度红线**：在 `AGENTS.md` 写入《移动端防挤压与抽屉键盘避让红线》。

**Non-Goals:**
- 不改变分类、房屋、房间的数据结构及后端 API。

## Decisions

### 1. 抽屉键盘避让采用“单层顶起 + 自适应高度”范式
- **决策**：
  - 移除所有在 `ShadSheet.child` 内部手动编写的 `bottom: MediaQuery.of(context).viewInsets.bottom`，仅保留正常的微量内容 padding（如 8~12dp）；
  - 为 `ShadSheet` 显式设置 `isScrollControlled: true`；
  - 在 `actions` 区域配置 `actionsAxis: Axis.horizontal`，让“取消”和“创建/保存”按钮横向并排分布，高度由 90dp 降低到 40dp。
- **原因**：让中间的可滚动视口拥有至少 160dp 以上的垂直舒适空间，输入框无论如何滚动都不会被底部操作栏截断下半部分。

### 2. 操作交互收拢：卡片行内采用“状态胶囊 + `...` 按钮”
- **决策**：卡片右侧仅放置两项元素：一个小巧精致的状态胶囊（`启用` / `停用`）以及单枚 `...` 按钮，点击滑出 `CategoryActionMenuSheet`。

### 3. 排序交互：采用 `ReorderableListView.builder`
- **决策**：使用长按拖拽重排配合拖拽把手图标，废弃卡片内部的上下箭头。

### 4. 规范写入：将《移动端防挤压与抽屉键盘避让红线》写入 `AGENTS.md`
- **决策**：在 `AGENTS.md` 中固化相关红线条款，约束全场景移动端开发。

## Risks / Trade-offs

- **[横屏与窄屏适配]** → `isScrollControlled: true` 配合 `SingleChildScrollView` 可确保在 360dp 竖屏与极端小屏下均可平滑滑动查看表单所有字段，操作按钮始终触手可及。
