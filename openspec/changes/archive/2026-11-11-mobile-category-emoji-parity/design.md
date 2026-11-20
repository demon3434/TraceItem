## Context

背景与动机见 `proposal.md`。现状与约束要点如下：
- Web 端 [EmojiPickerPopover.vue](file:///e:/code/TraceItem/web/src/components/ui/EmojiPickerPopover.vue#L121-L188) 定义了 6 大分组、每组 32 个、合计 192 个分类 Emoji 图标，并以「图标触发按钮 + 弹出选择器」同时服务于新建与编辑。
- 移动端 [category_manage_screen.dart](file:///e:/code/TraceItem/mobile/lib/screens/category_manage_screen.dart) 当前源码已达 427 行（受单文件 `<500` 行红线约束），若直接内嵌 192 款图标常量与分组网格选择器将突破行数上限。
- 移动端应用根组件使用 `ShadApp`，`ShadSheet` 弹出路由中无 `Material` 祖先，选择器内部可点击项必须采用 `GestureDetector` / `ShadButton` 等无 `Material` 依赖的组件，避免 Release 包出现构建异常占位符。

## Goals / Non-Goals

**Goals:**
- 移动端分类图标词库与 Web 端 `EmojiPickerPopover.vue` 的 6 大分组（共 192 款 Emoji）在分组名称、分组图标及每组元素顺序上保持 100% 精确一致。
- 移动端新建分类与编辑分类复用同一套 `ShadSheet` 分组图标选择器，交互入口统一采用「图标预览触发按钮 + 底部抽屉」（方式 A）。
- 遵循单文件 `<500` 行、`ShadSheet` 弹出层规范、最小字号 `>=12px`、多巴胺主题色联动及按压触觉反馈标准。

**Non-Goals:**
- 不改动后端数据库表结构或新增图标下发 API。
- 不调整 Web 端现有分类管理 UI 或图标词库。
- 本次变更不涉及房屋/房间图标选择器（`HouseRoomFormSheet`）的词库重构。

## Decisions

1. **静态常量模块化拆分（独立数据源文件）**
   - **决策**：新增 `mobile/lib/core/category_emojis.dart`（或 `mobile/lib/models/` 配套常量模块），用强类型结构定义 6 个分组（`name`、`icon`、`label`、`emojis`），与 Web 端 `emojiCategories` 逐项 1:1 对齐。
   - **替代方案**：由后端接口统一下发图标列表。因图标属于纯客户端 UI 选图词库、无动态运营后台需求，静态常量可保证零网络延迟与离线可用；双端一致性通过自动化测试校验列表总数与分组条目。

2. **抽离独立 `ShadSheet` 分组选择器组件（方式 A）**
   - **决策**：新增 `mobile/lib/widgets/category_emoji_picker_sheet.dart`，封装基于 `ShadSheet` 的底部抽屉选择器：
     - 顶部保留抽屉标题（「挑选分类小图标」）与副标题（「共 192 款精选图标」）。
     - 中上部为 2 行 × 3 列的 6 大主题分组胶囊按钮，自动联动 `ThemeController.instance.current` 多巴胺主题色高亮。
     - 中部为定高（或自适应视口上限）网格区域展示当前分组全部 32 款图标，支持流畅上下滑动或紧凑 6/8 列网格浏览，选中态带主题边框与背景高亮，点击触发 `HapticFeedback.lightImpact()` 并通过回调/返回值返回选中 Emoji。
     - 底部展示「当前图标」预览。
   - **替代方案**：在顶部新建卡片保留横向 18 个图标条 +「更多」按钮。放弃该方案是因为方式 A 更简洁、手机竖屏/横屏空间利用率更高，且新建与编辑体验完全统一。

3. **新建与编辑入口统一触发按钮布局**
   - **决策**：改造 [category_manage_screen.dart](file:///e:/code/TraceItem/mobile/lib/screens/category_manage_screen.dart)：
     - 顶部「新增私有物品分类」卡片移除横向 `_quickEmojis` 滚动条，改为「当前图标按钮（44×44+ 热区，默认 `📦`） + 名称 `ShadInput` + 添加 `ShadButton`」紧凑一行（窄屏可保持按钮清晰不挤压）。
     - `_handleEdit` 打开的「修改物品分类」`ShadSheet` 同样移除 `Wrap` 平铺列表，改为「当前图标按钮 + 名称 `ShadInput`」，点击图标按钮弹出 `CategoryEmojiPickerSheet`。

## Risks / Trade-offs

- **嵌套 `ShadSheet` 导航栈行为** → 编辑分类时先打开「修改物品分类」`ShadSheet`，点击图标按钮会再弹出「挑选分类小图标」`ShadSheet`。需确保选择器内只执行 `Navigator.of(sheetCtx).pop(selectedEmoji)`，不误关闭外层编辑抽屉，并在 Widget 测试中重点验证“打开编辑抽屉 -> 打开图标选择器 -> 选定图标 -> 仅关闭图标选择器且编辑抽屉回显新图标 -> 保存提交”。
- **双端词库未来漂移风险** → 后续若扩展 Web 端 `EmojiPickerPopover.vue`，需同步更新 `mobile/lib/core/category_emojis.dart`；可在测试文件中使用显式断言锁定分组数（6 组）、每组数量（32 个）及总数量（192 个）和关键首尾条目。

