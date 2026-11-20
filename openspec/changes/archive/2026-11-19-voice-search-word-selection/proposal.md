## Why

当前端侧语音识别（如 `SenseVoiceSmall`）会输出带标点的完整口语长句（例如“大便。”或“帮我找一下去年的红围巾放在哪了？”），直接填入搜索框会导致 SQLite FTS5 整句匹配失败；同时，语音浮层左上角展示的“引擎: xxx”标签既遮挡后方空间标题又对普通用户无意义，且识别完成后缺少选词确认环节。

## What Changes

- **精简语音浮层顶部 UI**：移除 `VoiceSearchOverlay` 左上角的“引擎: xxx”标签，仅保留右上角关闭按钮。
- **新增端侧智能分词与私域热词锚定（`VoiceQueryTokenizer`）**：
  - 自动清洗标点符号（`，。？！` 等）与口语头尾废话（如“帮我找一下”、“放在哪了”、“在哪里”）；
  - 优先利用本地已缓存的物品名、品牌、分类与房间名称作为私域自定义词典进行精确锚定（高置信词排首位）；
  - 结合轻量中文切分与停用词过滤输出 4~8 个高价值候选字词/短语。
- **浮层内原地选词确认交互**：
  - 语音识别完成后，原中部“按住下方按钮说话”提示框内容消失，原地切换为**分词候选词选择面板**：支持大字号多巴胺胶囊点选（可多选，命中词默认预选）、可微调预览输入框、「重新说话」与「确认并搜索」按钮；
  - 点击「确认并搜索」后将选中词填入首页搜索框并立即触发检索。
- **多词空格 `AND` 与全字段中文子串 FTS5 检索根治**：
  - 升级 `server/app/db/init_db.py` 与 `server/app/services/search_service.py`：保留 `unicode61` 分词器，在写入/同步 `items_fts` 时由 Python 侧将**物品名、品牌、位置细节、备注、房屋名、房间名、分类名、标签名**统一做 CJK 单字/二元空格切分索引（并在启动/增删改时自动同步），彻底解决中文 1~N 字任意子串与空间/分类/品牌搜索不到的问题；
  - 服务端与移动端 `OfflineDb.getCachedItems` 均支持按空格拆分多词 `AND` 检索与全字段匹配。
- **选词卡片精简与首页筛选栏重构**：
  - 精简 `VoiceWordPickerCard` 信息层级，候选词区支持 `maxHeight` 限制下的可滚动 `Wrap` 展示，修复“重说”按钮文字裁切；
  - 重构 `SpaceAnchorBar` 与 `HomeSearchBar`：顶部第一行将“全部房间”升级为动态房间下拉选择胶囊，并将分类筛选按钮 `🏷️` 移至其右侧；删除第二行房间横滑胶囊；搜索文本框拉宽占满左侧空间并紧挨麦克风按钮。
- **UI 组件与规范确认**：全端交互统一采用 `shadcn_ui`（`ShadButton`、多巴胺圆润大圆角胶囊与 `CustomDialogs.showToast`），图标 100% 使用 Lucide Icons，严禁任何原生 `alert` / `confirm` 弹窗。

## Capabilities

### New Capabilities
- `voice-query-tokenization`: 端侧标点清洗、私域词典优先匹配、中文口语分词与多词空格联合检索能力。

### Modified Capabilities
- `mobile-voice-search`: 移除浮层左上角引擎名称标签；语音识别完毕后在原提示框位置展示分词候选词与选词确认控件，用户确认后再填入首页搜索框触发检索。

## Impact

- 移动端：
  - `mobile/lib/core/voice_query_tokenizer.dart`（新增端侧分词与私域词典匹配工具）
  - `mobile/lib/widgets/voice_word_picker_card.dart`（新增选词确认卡片组件，保证单文件 < 500 行）
  - `mobile/lib/widgets/voice_search_overlay.dart`（移除引擎标签、接入识别完成选词态）
  - `mobile/lib/widgets/space_anchor_bar.dart`、`mobile/lib/widgets/home_filter_sheets.dart`（房间下拉、分类右移、移除第二行横轨、搜索框拉宽）
  - `mobile/lib/screens/home_screen.dart`、`mobile/lib/core/offline_db.dart`（传入本地热词并支持全字段多词空格过滤）
- 服务端：
  - `server/app/db/init_db.py`、`server/app/services/search_service.py`、`server/app/api/items.py`（全字段 CJK 1-gram/2-gram FTS5 索引同步与多词 `AND` 检索）

