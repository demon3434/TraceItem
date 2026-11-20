## Why

当前 Web 端物品分类管理已内置 **6 大主题分组 × 32 款 = 192 款精选 Emoji 图标**（位于 `web/src/components/ui/EmojiPickerPopover.vue`），而移动端 [category_manage_screen.dart](file:///e:/code/TraceItem/mobile/lib/screens/category_manage_screen.dart) 仅硬编码了 18 个扁平图标，导致用户在手机端新建或修改物品分类时无法选用与 Web 端一致的丰富图标，双端体验存在明显割裂。

## What Changes

- 将 Web 端 `EmojiPickerPopover.vue` 中的 6 大分组（玩具游乐、动物萌宠、零食美味、生活居家、文创装扮、探索自然）共 192 款精选 Emoji 按完全一致的分组顺序与图标顺序抽取为移动端共享常量数据模块。
- 新增独立的移动端分类图标选择器底部抽屉组件（基于 `ShadSheet` 与 `ShadButton` 等规范组件构建，零原生 `alert`/`confirm` 弹窗），支持 6 大分组切换、网格直观选图、当前选中图标高亮与触觉反馈（`HapticFeedback`）。
- 改造移动端物品分类管理页的新建栏与编辑抽屉，统一采用「方式 A」交互：在输入框左侧放置当前图标预览按钮（默认 `📦`），点击后打开统一的 `ShadSheet` 分组图标选择器抽屉，替换原有 18 图标横向快选条与 `Wrap` 平铺列表。
- 保持所有新建与修改的移动端源码文件严格低于 500 行，并补充自动化单元/Widget 测试校验双端 192 款图标数据一致性与交互流程。

## Capabilities

### New Capabilities

### Modified Capabilities
- `category-and-tag-system`: 新增对双端分类管理中 6 大分组共 192 款精选 Emoji 图标库及分组选择交互的一致性要求。

## Impact

- **移动端代码**：`mobile/lib/screens/category_manage_screen.dart` 及新增的常量与 `ShadSheet` 选择器组件文件（`mobile/lib/core/` 或 `mobile/lib/widgets/`），以及 `mobile/test/` 下的回归测试。
- **Web 端代码**：无代码改动，以 `web/src/components/ui/EmojiPickerPopover.vue` 现有 6 组 192 款图标作为基准对齐。
- **后端 / 数据库**：无 API 或表结构变更，沿用现有分类增改接口传输 Emoji 字符串。

