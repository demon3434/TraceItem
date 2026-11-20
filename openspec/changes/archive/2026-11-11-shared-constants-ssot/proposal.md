## Why

目前 TraceItem 的 Web 端、Mobile 端与 Server 端存在多处完全重复或已出现漂移的硬编码共享数据——包括 **6 组 192 款分类 Emoji**、**房屋与房间空间图腾 Emoji**（Web 端 15 个房间 vs Mobile 端 18 个房间已不一致）、**多巴胺主题配色**、**14 套预设默认分类**及**端侧多媒体压缩参数**。每次调整需要多端分别修改，极易遗漏；因此需要建立跨端共享单一数据源（SSOT）机制，将其写入项目全局约束，并完成全端重构、186 服务器部署与 Release 打包。

## What Changes

- 在仓库根目录新建 `shared/` 作为跨端唯一权威数据源目录，沉淀以下共享 JSON 文件：
  - `shared/category_emojis.json`：6 大分组 × 32 款 = 192 款分类 Emoji，以及预设分类名与推荐图标映射。
  - `shared/space_emojis.json`：统一的 10 款房屋建筑图标与全量合并去重后的功能房间图标（含中文名称映射）。
  - `shared/themes.json`：7 套核心多巴胺活力主题完整色板与渐变配置，及 Web 端扩展 `shadcn` 12 色系定义。
  - `shared/preset_categories.json`：14 套系统默认预设分类模板（名称、Emoji 图标、排序）。
  - `shared/media_limits.json`：图片/音频/视频端侧压缩与时长规格参数。
- 新增 `scripts/sync_shared.py` 同步生成脚本，将 `shared/*.json` 自动生成为 Mobile 端强类型 Dart 常量文件（`mobile/lib/core/generated/*.g.dart`）与 Server 端 Python 常量（`server/app/db/constants.py`），并提供 `--check` 校验模式防止文件漂移。
- 更新 Web 端配置（`web/vite.config.ts`、`web/tsconfig.json`）通过 `@shared` 别名直接导入 `shared/*.json`，重构 `EmojiPickerPopover.vue`、`CategoryTemplatePanel.vue`、`HouseRoomDialog.vue` 与 `theme.ts` 移除重复硬编码（保持 `shadcn-vue` 自定义浮层交互，零原生 `alert`/`confirm`）。
- 更新 Mobile 端引用（`category_emojis.dart`、`house_room_form_sheet.dart`、`theme_controller.dart`、`constants.dart`）消费自动生成的 Dart 共享常量（保持 `ShadDialog`/`ShadSheet` 弹出层及单文件 `<500` 行约束）。
- 将「双端/全端共用硬编码必须抽离至 `shared/` 单一数据源并执行同步校验」写入全局最高约束文档 `AGENTS.md` 与 `openspec/config.yaml`。
- 补充双端及跨端同步一致性自动化测试，重新构建 Web 并通过 `scripts/deploy_to_186.py` 部署到 `192.168.7.186`，以及构建 ARMv8 Release APK。

## Capabilities

### New Capabilities
- `shared-constants-ssot`: 定义跨端共享常量单一数据源（`shared/*.json`）、同步生成与一致性校验规范，确保分类/空间 Emoji、主题配置、预设分类及媒体规格在 Web、Mobile 与 Server 三端完全一致。

### Modified Capabilities

## Impact

- **新增目录与脚本**：`shared/*.json`、`scripts/sync_shared.py`、`mobile/lib/core/generated/*.g.dart`。
- **Web 端重构**：`web/vite.config.ts`、`web/tsconfig.json`、`web/src/components/ui/EmojiPickerPopover.vue`、`web/src/components/admin/CategoryTemplatePanel.vue`、`web/src/components/space/HouseRoomDialog.vue`、`web/src/stores/theme.ts`。
- **Mobile 端重构**：`mobile/lib/core/category_emojis.dart`、`mobile/lib/widgets/house_room_form_sheet.dart`、`mobile/lib/core/theme_controller.dart`、`mobile/lib/core/constants.dart`，以及配套测试。
- **Server 端**：`server/app/db/constants.py`（由 `shared/preset_categories.json` 同步生成）。
- **全局规范与交付物**：`AGENTS.md`、`openspec/config.yaml`、`192.168.7.186` 线上环境更新及 `mobile/build/app/outputs/flutter-apk/app-release.apk`。

