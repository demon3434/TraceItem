# Tasks

## 1. 抽取移动端分类操作抽屉组件

- [x] 1.1 在 `mobile/lib/widgets/category_action_sheet.dart` 中实现 `CategoryActionMenuSheet`，基于 `ShadSheet` 与 `ShadSheetOptionTile` 提供“修改名称与图标”、“切换启用/停用状态”、“解绑删除”等选项，并对危险操作标红及加入触觉反馈；通过组件单元编译验证。

## 2. 重构分类管理界面布局与交互

- [x] 2.1 改造 `mobile/lib/screens/category_manage_screen.dart` 的卡片水平 `Row` 布局，彻底移除行内平铺的 5 个 `IconButton`，对分类名称与状态描述添加 `maxLines: 1` 与 `overflow: TextOverflow.ellipsis` 防御保护，并在右侧集成状态胶囊 Badge 与 `...` 更多操作按钮；通过 flutter analyze 校验无排版越界告警。
- [x] 2.2 将分类列表重构为 `ReorderableListView.separated`，支持卡片长按拖拽重排并在回调中调用 `ApiService.updateCategory` 更新排序次序，废弃旧有的上下移动逻辑与按钮；通过界面拖拽交互与网络请求调用链验证。
- [x] 2.3 在 `category_manage_screen.dart` 中接入 `CategoryActionMenuSheet`，点击 `...` 或卡片时调起操作抽屉，无缝连接现有编辑表单弹窗和 `CustomDialogs.showConfirm` 安全删除逻辑；通过功能流程走查验证。

## 3. 根治移动端抽屉表单键盘避让与输入框视口截断

- [x] 3.1 改造 `mobile/lib/widgets/house_room_form_sheet.dart`，开启 `isScrollControlled: true`，清理内部多余的 `MediaQuery.of(context).viewInsets.bottom`，并将操作按钮改为水平紧凑排列（`actionsAxis: Axis.horizontal`），消除视口下部截断；通过静态分析与构建验证。
- [x] 3.2 改造 `mobile/lib/screens/category_manage_screen.dart` 中的修改分类抽屉表单，开启 `isScrollControlled: true`，移除内层冗余 `viewInsets.bottom`，保持全端抽屉表单键盘避让逻辑 100% 统一；通过编译与走查验证。

## 4. 全局规范固化与验证

- [x] 4.1 在项目根目录 `AGENTS.md` 的“移动端 (Flutter) 旗舰级 UI 工艺与微交互硬性约束”小节中追加《移动端防挤压与触控热区约束红线》（禁止行内堆叠多按钮、强制动态文本单行截断、排序采用手势拖拽），确保后续开发无死角遵守。
- [x] 4.2 在 `AGENTS.md` 中补充《移动端半屏表单抽屉软键盘自适应避让规范》（严禁内部二次叠加 viewInsets、强制开启 isScrollControlled、紧凑按钮排列避免视口裁剪）。
- [x] 4.3 运行全套静态分析（`flutter analyze`）、自动化单元测试与 OpenSpec 校验，并重新构建 ARMv8 Release APK。
