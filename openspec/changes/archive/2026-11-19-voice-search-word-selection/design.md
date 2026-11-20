## Context

动机与背景见 `proposal.md`（Why）。当前 `VoiceSearchOverlay`（407 行）已接近 500 行单文件红线，且真机截图反映两个问题：
1. 浮层左上角的 `引擎: SenseVoiceSmall (int8)` 胶囊遮挡背景空间栏，且用户无需关心底层引擎名称；
2. 语音识别完毕后直接把带标点的原始文本（如 `"大便。"`）填入搜索框，导致搜索体验不佳且无法筛选关键短语。

## Goals / Non-Goals

**Goals:**
- 移除 `VoiceSearchOverlay` 左上角引擎名称标签，保持顶部极简；
- 新增 `VoiceQueryTokenizer` 纯 Dart 端侧分词器（< 220 行），支持去标点、口语模板剥离、私域热词（本地缓存物品/品牌/分类/房间名）优先锚定与轻量切分；
- 新增 `VoiceWordPickerCard` 组件（< 240 行），在识别完成后原地替换原中部提示框，提供多选大号胶囊（命中词默认预选）、可微调预览输入框、「重新说话」与「确认并搜索」；
- 同步增强服务端 `search_service.py` 与端侧 `OfflineDb.getCachedItems`，支持空格分隔多词 `AND` 联合检索。

**Non-Goals:**
- 不引入重型外部中文分词依赖包（如 5MB+ 完整 Jieba 词库），保持端侧包体轻量与零启动耗时；
- 不改变「设置 → 语音识别模型」的模型管理能力。

## Decisions

### 1. 端侧分词算法设计（`VoiceQueryTokenizer`）
- **选择**：四级流水线（纯 Dart 内存计算，耗时 < 3ms）：
  1. **标点与空白规范化**：去除全部中英文标点（`，。？！、；：“”‘’（）().,?!;:'"`）；
  2. **口语头尾剥离**：正则移除常见寻物前缀（`帮我找一下|我想找|找一下|请问|看看`）与后缀（`放在哪儿了|放在哪了|在哪里|在哪儿|在哪|放哪了|去哪了`）；
  3. **私域词典最长优先匹配**：传入当前用户的 `items` 名称/品牌与 `categories`、`rooms` 名称集合，按长度降序扫描文本，命中项直接标记为 `isDomainHit: true`（高置信推荐）并置顶；
  4. **通用切分与组合**：对剩余片段过滤常见单字停用词（`的|了|在|是|把|个|些|这|那|去年|今年`），保留 2~4 字词组、完整清洗短语以及连续中文的二元切分片段（去重并限制总数 <= 8 个），确保用户一定能点选出想要的字词短语。
- **理由**：家庭寻物场景词表高度集中于用户自建物品库，私域热词锚定准确率远高于通用新闻分词，且 100% 离线零延迟。

### 2. 原地切换选词态（不额外弹窗）
- **选择**：在 `VoiceSearchOverlay` 增加 `_VoiceModeState.picking` 状态。识别返回非空文本后，不关闭浮层，而是隐藏底部大麦克风按钮与原提示文案，在原中部白色圆角卡片区域原地渲染 `VoiceWordPickerCard`（利用 `AnimatedSwitcher` 平滑过渡）。
- **理由**：严格响应用户反馈（“语音识别完毕，绿框中的内容消失，这里展示分词结果及选词相关的控件”），避免再弹一层新弹窗造成视觉跳跃。

### 3. 全字段 CJK 1-gram/2-gram FTS5 索引与多词检索
- **选择**：
  - **服务端 `items_fts` 方案 2**：保留 `tokenize = 'unicode61'`，增加 `extra_text`（或将 `name / brand / location_detail / description / house_name / room_name / category_name / tag_names` 统一通过 Python `cjk_index_text()` 展开为原词 + 1-gram + 2-gram 空格分隔串）写入 `items_fts`，在服务启动时与物品增删改/空间分类改名时自动同步，彻底解决中文单字/后缀/中间子串及空间/分类/品牌搜索不到的问题；
  - **查询侧**：`search_service.py` 将输入按空格拆为 `terms`，FTS5 构造 `"term1"* AND "term2"*`；`LIKE` 回退同步关联 `House.name`、`Room.name`、`Category.name` 与 `Tag.name`；
  - **移动端 `OfflineDb.getCachedItems`**：将 `houseName`、`roomName`、`categoryName`、`tags` 纳入 `haystack` 并按空格 `AND` 过滤。

### 4. 选词卡片精简与首页顶部栏重构
- **选词卡片**：精简顶部为单行识别原文，候选词区外层包裹 `ConstrainedBox(maxHeight: 156)` + `SingleChildScrollView` 支持多候选词平稳滚动，底部 `重说` + `确认搜索` 按钮确保不裁切文字；
- **首页顶部栏**：`SpaceAnchorBar` 第一行展示 `[房屋 ⌄] > [房间 ⌄] [🏷️ 分类]`（选中房间时保留紧凑锚定按钮），移除第二行房间横滑胶囊；`HomeSearchBar` 搜索框占满左侧全部宽度紧挨右侧麦克风按钮。

## Risks / Trade-offs

- **[Risk] 用户只想说一个短词（如“大便”），如果强行切太碎会显得啰嗦** → 当清洗后文本长度 <= 4 且未切出多余子词时，仅展示清洗后的整词（并默认预选），用户直接点一次「确认并搜索」即可。
- **[Risk] `voice_search_overlay.dart` 接近 500 行** → 将分词逻辑抽离到 `mobile/lib/core/voice_query_tokenizer.dart`，将选词卡片 UI 抽离到 `mobile/lib/widgets/voice_word_picker_card.dart`，保证每个文件均在 420 行以内。

