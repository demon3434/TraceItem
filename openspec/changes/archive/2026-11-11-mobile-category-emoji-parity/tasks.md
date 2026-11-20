## 1. 分类 Emoji 词库常量抽离与双端对齐

- [x] 1.1 新增 `mobile/lib/core/category_emojis.dart`，按 `web/src/components/ui/EmojiPickerPopover.vue` 的顺序完整定义 6 大分组（`toys` 玩具游乐、`animals` 动物萌宠、`sweets` 零食美味、`home` 生活居家、`art` 文创装扮、`nature` 探索自然）共 192 款精选 Emoji（每组 32 款），并确保文件行数严格小于 500 行；通过静态检查及测试断言验证分组数（6 组）与总数（192 款）无遗漏。

## 2. 移动端 ShadSheet 分组图标选择器组件

- [x] 2.1 新增 `mobile/lib/widgets/category_emoji_picker_sheet.dart`（严格小于 500 行），基于 `ShadSheet` 实现底部弹出选择器：包含标题与「共 192 款精选图标」副标题、2×3 六大主题分组切换按钮（绑定 `ThemeController` 多巴胺主题色高亮）、当前分组 32 款图标网格（不依赖 `Material` 的 `GestureDetector` + `AnimatedScale` + `HapticFeedback.lightImpact()`、字号 `>=12px`、圆角 `12~24px`），以及底部「当前图标」预览条；选定后仅关闭自身抽屉并回传所选 Emoji，通过 `flutter analyze` 验证无警告。

## 3. 分类管理页交互重构（方式 A）

- [x] 3.1 改造 `mobile/lib/screens/category_manage_screen.dart`（保持总行数严格小于 500 行）：移除 `_quickEmojis` 18 图标列表、顶部横向滚动快选条及编辑 `ShadSheet` 内的 `Wrap` 平铺列表；在「新增私有物品分类」输入框左侧与「修改物品分类」`ShadSheet` 输入框左侧统一放置当前图标触发按钮（`44×44` 以上触控热区），点击后调用 `CategoryEmojiPickerSheet` 更新所选图标，确保在纯 `ShadApp` 环境下正常弹出与回显。

## 4. 自动化测试与静态验证

- [x] 4.1 新增 `mobile/test/category_emoji_picker_test.dart`，校验 `kCategoryEmojiGroups` 严格包含 6 个分组、每组 32 个、合计 192 个且与 Web 端基准一致；并编写 Widget 测试覆盖“新建栏点击图标按钮打开 `ShadSheet` 切换分组选图”与“编辑抽屉内嵌套打开图标选择器选图并保存”交互。
- [x] 4.2 运行 `flutter analyze` 与全量 `flutter test` 验证无错误且全部测试通过，并统计所有新增和修改文件的行数确认均小于 500 行。

