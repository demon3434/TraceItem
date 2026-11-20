## 1. 建立 shared/ 单一数据源与同步生成脚本

- [x] 1.1 在根目录创建 `shared/category_emojis.json`、`shared/space_emojis.json`、`shared/themes.json`、`shared/preset_categories.json` 与 `shared/media_limits.json`，完整沉淀 6 组 192 款分类 Emoji（含预设分类与图标映射）、合并去重后的房屋/房间空间图腾、7 套多巴胺主题（含 Web 端 `shadcn` 扩展色系）、14 套默认预设分类及多媒体压缩限制参数，并校验所有 JSON 语法合法。
- [x] 1.2 新增 `scripts/sync_shared.py`（严格 `<500` 行），实现从 `shared/*.json` 幂等生成 `mobile/lib/core/generated/shared_*.g.dart` 与 `server/app/db/constants.py`，并支持 `--check` 校验模式；运行 `python scripts/sync_shared.py` 及 `--check` 验证退出码为 0。

## 2. Web 端引用共享数据

- [x] 2.1 更新 `web/vite.config.ts` 与 `web/tsconfig.json`，配置 `@shared` 路径别名指向 `../shared`，通过 `npm run build` 前置校验解析无报错。
- [x] 2.2 改造 `web/src/components/ui/EmojiPickerPopover.vue`、`web/src/components/admin/CategoryTemplatePanel.vue`、`web/src/components/space/HouseRoomDialog.vue` 与 `web/src/stores/theme.ts`，改为直接导入 `@shared/*.json` 消费共享常量（保持 `shadcn-vue` 浮层与零原生 `alert`/`confirm` 约束，单文件 `<500` 行），运行 `cd web && npm run build` 验证构建成功。

## 3. Mobile 端与 Server 端引用共享数据

- [x] 3.1 改造 `mobile/lib/core/category_emojis.dart`、`mobile/lib/widgets/house_room_form_sheet.dart`、`mobile/lib/core/theme_controller.dart` 与 `mobile/lib/core/constants.dart`，改为引用 `mobile/lib/core/generated/shared_*.g.dart` 强类型常量（保持 `ShadSheet`/`ShadDialog`、多巴胺主题联动及单文件 `<500` 行约束），运行 `flutter analyze` 验证零警告。
- [x] 3.2 验证 `server/app/db/constants.py` 与 `shared/preset_categories.json` 同步一致，并在 `server/` 运行后端测试确认开户派生 14 个预设分类逻辑正常通过。

## 4. 全局约束文档固化与跨端校验测试

- [x] 4.1 更新 `AGENTS.md` 与 `openspec/config.yaml`，将「双端/三端共用常量（Emoji 映射、空间图腾、多巴胺主题、预设模板、媒体规格等）必须放入 `shared/*.json` 单一数据源并通过 `scripts/sync_shared.py` 同步与校验」写入全局硬性开发约束。
- [x] 4.2 新增或更新 `mobile/test/shared_constants_sync_test.dart`（及更新 `mobile/test/category_emoji_picker_test.dart`），直接比对 `shared/*.json` 与移动端生成常量，以及运行 `python scripts/sync_shared.py --check`、`flutter test` 验证全部通过且所有改动文件均 `<500` 行。

## 5. 部署 186 服务器与生成 Release APK

- [x] 5.1 执行 `cd web && npm run build` 更新生产静态产物后，运行 `python scripts/deploy_to_186.py` 将最新后端与 Web 部署至 `192.168.7.186`，并检查 `/health` 与页面响应正常。
- [x] 5.2 在 `mobile/` 执行 `flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation` 生成 ARMv8 Release APK，验证 `mobile/build/app/outputs/flutter-apk/app-release.apk` 生成成功。

