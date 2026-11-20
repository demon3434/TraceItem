## Context

动机与问题背景见 `proposal.md`。技术现状与关键约束如下：
- 仓库包含三个独立运行环境：`web/`（Vue 3 + TypeScript + Vite）、`mobile/`（Flutter / Dart）、`server/`（FastAPI / Python + Docker）。
- Vite 与 TypeScript（`web/tsconfig.json` 已开启 `resolveJsonModule: true`）可以直接导入仓库根目录的 JSON 文件；而 Flutter 的资源打包器不支持引用 `mobile/` 包目录外的 `../shared/` 路径，且 `Dockerfile` 仅拷贝 `server/` 与 `web/dist/`。
- 所有新增与修改文件必须严格遵守单文件 `<500` 行约束；客户端弹出层必须保持 `shadcn-vue` 与 `ShadDialog`/`ShadSheet`，严禁引入原生 `alert`/`confirm`。

## Goals / Non-Goals

**Goals:**
- 建立 `shared/*.json` 单一数据源 + `scripts/sync_shared.py` 生成与校验机制，彻底消除 Web / Mobile / Server 对同一批常量的重复硬编码。
- 在保持现有对外接口与交互规范不变的前提下，对齐并合并 Web 与 Mobile 的房间 Emoji 列表、多巴胺主题色板、分类 Emoji 映射、14 个预设分类与媒体压缩参数。
- 将「共用常量必须放入 `shared/` 并同步」持久化写入 `AGENTS.md` 与 `openspec/config.yaml` 全局约束。
- 完成 Web 构建、186 服务器部署验证以及 Android ARMv8 Release APK 打包。

**Non-Goals:**
- 不将静态图标与主题配置改造为需要联网才能读取的后端动态配置接口（避免登录前离线切换主题或选图受阻）。
- 不调整 Web 端特有的 `shadcn` 12 色系在移动端的展示范围（Mobile 主题设置页仍仅展示 7 套多巴胺主题，Web 端从同一份 `themes.json` 读取 `dopamine` + `shadcn` 两组）。

## Decisions

1. **采用「根目录 JSON + 编译期代码生成」而非运行时跨目录读取**
   - **决策**：
     - `shared/` 存放 5 个职责清晰的 JSON：`category_emojis.json`、`space_emojis.json`、`themes.json`、`preset_categories.json`、`media_limits.json`。
     - **Web 端**：在 `web/vite.config.ts` 与 `web/tsconfig.json` 配置 `@shared` 别名指向 `../shared`，直接 `import` JSON，零构建中间文件。
     - **Mobile 端**：通过 `scripts/sync_shared.py` 生成纯静态 `const` Dart 文件至 `mobile/lib/core/generated/`（如 `shared_category_emojis.g.dart`、`shared_space_emojis.g.dart`、`shared_themes.g.dart`、`shared_media_limits.g.dart`），并由现有 `category_emojis.dart` / `theme_controller.dart` / `constants.dart` / `house_room_form_sheet.dart` 转发或引用。
     - **Server 端**：同样由 `scripts/sync_shared.py` 同步生成 `server/app/db/constants.py`（保持 `Dockerfile` 与 `scripts/deploy_to_186.py` 打包结构零破坏）。
   - **替代方案**：让 Flutter 在运行时通过 `rootBundle` 异步解析复制到 `mobile/assets/` 的 JSON。放弃该方案是因为异步加载会破坏 `const` 主题初始化与同步弹窗构建，增加首帧闪烁与测试复杂度。

2. **空间图腾（房屋/房间）取双端并集统一**
   - **决策**：对比 `HouseRoomDialog.vue`（10 房屋 / 15 房间）与 `house_room_form_sheet.dart`（10 房屋 / 18 房间），在 `shared/space_emojis.json` 中合并去重保留全部常见家庭空间（含 `🚀 秘密基地`、`🚪 玄关`、`🎨 画室`、`💼 办公区`、`☕ 茶水角`、`🍽️ 独立餐厅`、`🧰 工具间` 等），使双端房屋与房间图腾库 100% 对齐。

3. **自动化防漂移校验**
   - **决策**：`scripts/sync_shared.py --check` 负责校验生成目标与 `shared/*.json` 一致；同时在 `mobile/test/` 中补充一致性测试直接比对 `shared/*.json` 与生成常量，确保后续任何修改若忘记运行同步脚本会立即在测试阶段暴露。

## Risks / Trade-offs

- **忘记运行同步脚本导致三端短暂不一致** → 提供幂等的 `python scripts/sync_shared.py --check` 校验，并在 `AGENTS.md` 全局规范与测试套件中强制要求改动 `shared/*.json` 后立即运行同步脚本。
- **Web 端 `CategoryTemplatePanel.vue` 的 `quickEmojis` 与 `EmojiPickerPopover.vue` 并存** → 顺手将 `CategoryTemplatePanel.vue` 的预设快捷图标或图标选择接入 `shared/category_emojis.json`（或从中提取默认推荐列表），减少管理端模板面板的孤立硬编码。
- **部署到 186 服务器前需先重新构建 `web/dist`** → 任务清单中明确规定先执行 `npm run build` 更新 `web/dist`，再执行 `python scripts/deploy_to_186.py`，确保 186 上运行的是最新 Web 产物与 Server 代码。

