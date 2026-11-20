# 图觅 (TraceItem) Agent 开发与全局约束规范

本文档为“图觅”项目代码库的全局最高优先级开发准则。所有开发代理（Agents）与人类开发者在编写、修改代码时必须无条件严格遵守。

> [!IMPORTANT]
> **全场景生效声明**：
> 本规范**不仅适用于大型架构设计与 OpenSpec 提案流程，在日常对话中的任何局部调试、功能微调、Bug 修复或微小修改（哪怕只写一个函数、加一个弹窗、改一个组件）中，均必须 100% 绝对执行**。严禁以“临时改动”、“小改动”为由绕过任何一条红线！

---

## 🚨 全局硬性红线与约束 (Global Hard Constraints)

### 1. 单文件代码行数严格限制 (<500 行)
- **硬性红线**：**任何单个代码源文件（包括但不限于 Python、Dart/Flutter、Vue/TS、SQL、Shell）行数严禁超过 500 行。**
- **解耦拆分原则**：
  - **后端 (FastAPI)**：Router 只处理 HTTP 请求参数校验与响应封装（建议 <200 行）；复杂业务逻辑必须下沉到独立 Service；数据表模型与 Pydantic Schema 按业务实体分别独立建文件。
  - **移动端 (Flutter)**：Screen 页面仅组装布局，复杂卡片、列表项、多媒体控制条必须拆分成独立的 Widget 文件；端侧压缩、网络拦截、状态管理逻辑各自独立封装。
  - **Web 端 (Vue 3)**：View 页面组件必须拆分出子组件（如 `ItemCard.vue`、`MediaPreview.vue`、`BackupTable.vue`），每个 `.vue` 文件尽量控制在 300 行以内。

### 2. 交互红线：严禁原生 alert/confirm，必须使用统一设计弹出层
- **严禁调用浏览器原生弹窗**：在任何 Web 页面与客户端代码中，**严禁使用 `alert()`、`confirm()`、`prompt()` 等浏览器原生弹窗**。此类弹窗体验粗糙破环沉浸感。
- **强制使用统一美学弹出层与消息流**：
  - **确认对话框**：强制封装并调用统一的弹出层组件（Web 端使用 `ShadDialog` / `ConfirmDialog`；移动端使用 `ShadDialog`）；
  - **半屏操作抽屉**：用于房间选择、空间锚定、详情查看，强制采用温润大圆角的底部抽屉（Web/Mobile: `ShadSheet`）；
  - **消息通知与轻量提示**：统一使用屏幕底部轻量悬浮气泡 Toast（`CustomDialogs.showToast`），具备优雅的淡入滑出与触感，停留时长锁定为 1.2s~1.5s 短时展示，绝不长时间霸屏遮挡下层控件操作。

### 3. UI 界面美学与儿童友好设计准则 (Aesthetics & Kid-Friendly)
- **拒绝工程师原型风**：任何页面（无论是 Web 还是 App）禁止出现简陋无样式的表单、刺眼的纯黑细线边框或生硬的默认灰底。
- **全端统一设计底座**：
  - 移动端（Flutter）强制基于 [`shadcn_ui`](.agents/skills/shadcn-ui-flutter/SKILL.md) 构建；
  - 桌面 Web 端（Vue 3）强制基于 `shadcn-vue` 与 Tailwind CSS 构建；
  - 图标全端 100% 统一采用 **Lucide Icons**（圆润现代矢量图标）。
- **儿童友好与活力多巴胺色板**：
  - 必须采用 **18px ~ 24px 的温润大圆角 (Squircle)**，消除尖锐刺痛感；
  - 默认预设多套温馨活力主题（阳光暖橙、草莓甜心、薄荷清柠、星空城堡、雅致原木），支持一键切换；
  - 空间与分类必须支持 **Emoji 趣味图腾**（如 🧸 玩具角、🚀 秘密基地、🛋️ 大客厅），让孩子即使不认字也能秒认位置。
- **字号与可读性红线 (Typography Standard)**：
  - **严禁使用低于 12px (text-xs) 的极小字体（绝对严禁 `text-[10px]`）**；
  - 标准正文、表单输入框、下拉框、空间树列表与卡片描述必须使用 **14px ~ 16px (`text-sm` ~ `text-base`)**，标题使用 16px~22px，确保大屏与移动端高分屏下无需费力眯眼辨认；
  - 必须遵循技能标准：[`ui-typography-and-theming`](.agents/skills/ui-typography-and-theming/SKILL.md)。

### 4. 移动端 (Flutter) 旗舰级 UI 工艺与微交互硬性约束 (Mobile UI Craftsmanship)
- **漫反射光影与温润材质**：
  - 严禁使用生硬的纯黑描边与单层粗糙投影；
  - 所有卡片、悬浮栏必须采用 **双层漫反射柔和微光投影 (Ambient Double Shadow)**（主题主色 6% 透明度大模糊扩散 + 3% 黑色环境柔和投影）；
  - 外层大卡片与半屏抽屉必须使用 **`BorderRadius.circular(22~24)`**，药丸徽章使用 **`BorderRadius.circular(999)`**。
- **物理弹性手势与触觉反馈 (Scale-on-Press & Haptics)**：
  - 核心物品卡片与重要大按钮必须支持按下微缩动画（`AnimatedScale` 按下至 `0.965`，时长 120ms，松开平滑回弹）；
  - 点击卡片、切换房间胶囊必须附带轻微触觉反馈（`HapticFeedback.lightImpact()` / `selectionClick()`）；
  - 老幼长按语音寻物、完成保存登记必须附带适度触觉震动反馈（`HapticFeedback.mediumImpact()`）。
- **生动趣味空状态**：
  - 严禁使用毫无样式的单行灰字敷衍空状态；
  - 必须使用大尺寸生动 Emoji（🧸/🔍）、带有光晕的浅色彩底、温暖对话式文案与醒目的流光渐变引导大按钮。
- **移动端防挤压与触控热区约束红线 (Anti-Squish & Touch Target Safeguards)**：
  - **行内操作按钮数量硬约束**：严禁在移动端卡片或列表项的水平 `Row` 中横排平铺超过 1 个独立操作图标按钮；凡包含 2 个及以上操作项（如编辑、排序、停用、删除），强制收拢为单个 `...` 按钮，点击滑出温润大圆角半屏操作抽屉（`ShadSheet` + `ShadSheetOptionTile`），提供舒适大热区并杜绝触控误触；
  - **动态宽度文本防御规范**：任何嵌套在 `Row`、`Expanded`、`Flexible` 内的标题与描述文本，**必须显式声明 `maxLines: 1` 与 `overflow: TextOverflow.ellipsis`**，严禁留白放任文本在窄屏（如 360dp）下被挤压逐字折行塌陷成单字竖排；
  - **排序交互手势规范**：列表项重排一律采用 `ReorderableListView` 物理手势拖拽（配轻微触觉反馈 `HapticFeedback.lightImpact()`），严禁在卡片行内堆砌上下箭头图标按钮。
- **移动端半屏表单抽屉软键盘自适应避让与系统状态栏防重叠红线 (Sheet Keyboard Avoidance & Safe Area Standard)**：
  - **严禁裸调 `showShadSheet`**：移动端一切底部半屏抽屉必须强制调用全局封装的 `CustomDialogs.showModalSheet`，外层强制集成 `SafeArea(top: true, bottom: false, child: Padding(padding: EdgeInsets.only(top: 10), child: ...))`，彻底消除软键盘唤起将抽屉向上顶推时穿透/侵入系统通知栏（时间、电量、图标）的显示错乱与遮挡冲突；
  - **输入框左右边框防剪裁规范**：抽屉内的 `ShadSheet` 必须配置 `scrollPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)`，内容 `child` 必须预留至少 4px 水平呼吸内边距，严禁输入框左右边缘紧贴 `SingleChildScrollView` 的 `Clip.hardEdge` 物理剪裁边界，确保激活输入法后的高亮外框 100% 完整展现；
  - **严禁内部二次叠加 viewInsets**：由于外层已统一提供 `AnimatedPadding(bottom: viewInsets.bottom)` 抬高避让，**严禁在 `ShadSheet.child` 内部手动重复叠加 `MediaQuery.of(context).viewInsets.bottom`**，杜绝多重空白堆叠导致内容被顶出视口；
  - **强制开启高度自适应伸展**：凡包含表单输入项的半屏抽屉，**必须显式声明 `isScrollControlled: true`**，允许抽屉在键盘唤起时自适应向上扩展高度，严禁放任默认配置锁死在 9/16 屏高；
  - **操作栏紧凑横排防截断**：抽屉底部的确认/取消操作栏必须采用水平紧凑排列（`actionsAxis: Axis.horizontal`，`expandActionsWhenTiny: false`，`actionsPinned: false`），消除竖向堆叠霸占视口死区，确保文本输入框上下左右四周边框 100% 完整展现，绝对杜绝被视口底边缘物理剪裁截断。
- **强制约束遵循**：
  - 移动端一切界面重构与新增组件必须 100% 遵循技能标准：[`mobile-ui-craftsmanship`](.agents/skills/mobile-ui-craftsmanship/SKILL.md)。

---

## 🏛️ 核心架构与业务边界规范

1. **轻量化数据库 (SQLite 3 WAL + FTS5)**：
   - 严禁引入任何外部数据库容器（如 PostgreSQL/MySQL）；
   - 所有数据库连接初始化必须显式执行：
     ```sql
     PRAGMA foreign_keys = ON;
     PRAGMA journal_mode = WAL;
     PRAGMA synchronous = NORMAL;
     ```
   - 物品检索统一依赖 SQLite FTS5 全文索引虚拟表。

2. **空间层级与橱柜免配置原则**：
   - 数据库物理实体仅维护到房间：`House` (房屋) ➔ `Room` (房间)，二者均严格绑定 `user_id`；
   - 橱柜、抽屉、收纳箱**严禁在数据库建实体表**，完全由现场照片与短视频视觉直观展现。

3. **用户独立私有账本与 Admin 上帝视角**：
   - 普通成员之间数据默认互不穿透；
   - 仅 Admin 账号专享穿透全库的【上帝视角】紧急寻物接口。

4. **现代工业化存储路径**：
   - 多媒体物理存储严格按类型与年月分片：
     `/data/media/{images|audios|videos|thumbnails|backups}/{YYYY}/{MM}/{file_name}`
   - 严禁向单一目录平铺写入海量文件。

5. **多媒体端侧压缩与流媒体规范**：
   - 图片：JPEG 格式，长边限制 ≤1600px，画质 80%~85%；
   - 音频：AAC/M4A 格式，单声道 48kbps，时长 ≤60 秒；
   - 视频：优先 x265 (HEVC) 编码，720p，码率 1.0~1.5Mbps，时长 ≤15 秒；**必须 MOOV 前置（+faststart），关键帧间隔必须锁定为 1 秒**，杜绝拖拽卡顿。

6. **零算力损耗纯 TAR 备份**：
   - 严禁使用 ZIP 压缩；统一打包为无压缩 `.tar` 流；
   - 仅由 Admin 手动触发备份；必须具备历史备份记录列表与文件一键清理/防膨胀淘汰功能。

7. **移动端 Android Release 架构约束 (仅 ARMv8)**：
   - 构建移动端 Android Release APK 时**仅生成 `arm64-v8a` (ARMv8) 单架构包**，禁止打包 `armeabi-v7a` 或 `x86_64` 冗余架构；
   - 标准构建命令：`flutter build apk --release --target-platform android-arm64`（如遇本地 Gradle 版本校验提示可附加 `--android-skip-build-dependency-validation`）。

8. **双端/全端共用常量单一数据源约束 (SSOT)**：
   - 凡跨端（Web / Mobile / Server）共用的静态常量与映射表（包括但不限于分类 Emoji 图标库与分类映射、空间图腾 Emoji、多巴胺主题色板、系统预设分类模板、端侧多媒体压缩参数等），**严禁在多端各自重复硬编码**；
   - 必须统一沉淀至仓库根目录 [`shared/`](shared/) 下的 JSON 文件作为唯一权威数据源：
     - Web 端通过 `@shared/*.json` 直接导入消费；
     - Mobile 端与 Server 端严禁手动修改生成文件，必须运行 `python scripts/sync_shared.py` 自动同步生成 `mobile/lib/core/generated/shared_*.g.dart` 与 `server/app/db/constants.py`；
   - 修改 `shared/*.json` 或提交相关变更前，必须执行 `python scripts/sync_shared.py --check` 确认零漂移。

---

## 📚 决策文档索引
- 统一术语定义：[`GLOSSARY.md`](GLOSSARY.md)
- 详细架构决策记录：`docs/adr/0001` ~ `docs/adr/0010`
