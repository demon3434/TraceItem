## 1. 端侧智能分词器与全字段中文子串 FTS5 根治

- [x] 1.1 新建 `mobile/lib/core/voice_query_tokenizer.dart`：实现标点清洗、口语前后缀剥离、私域热词（物品名称/品牌/分类/房间）最长优先锚定与轻量中文切分，输出带 `isDomainHit` 标记的 `VoiceTokenCandidate` 列表（最多 8 个），并编写单元测试验证典型口语长句与短词场景。验证：文件行数 < 500 行，`flutter test` 分词用例全部通过。
- [x] 1.2 升级服务端 FTS5 全字段 CJK 1-gram/2-gram 索引（`server/app/db/init_db.py`、`server/app/services/search_service.py` 及 `items` 增删改同步钩子）：保留 `unicode61`，写入/启动同步时将物品名、品牌、位置细节、备注、房屋名、房间名、分类名、标签名切分为 CJK 单字/双字索引串，彻底根治中文任意子串与空间/分类/品牌检索；同步升级 `mobile/lib/core/offline_db.dart` 支持全字段多词 `AND` 检索。验证：单字/后缀子串/房间名/分类名/空格多词在服务端与端侧均命中。

## 2. 语音选词卡片精简与首页筛选栏重构

- [x] 2.1 优化 `mobile/lib/widgets/voice_word_picker_card.dart`：精简顶部冗余标题，候选词区外层包裹 `ConstrainedBox(maxHeight: 156)` + `SingleChildScrollView` 支持多词自适应滚动，修复底部“重说”按钮文字裁切。验证：文件行数 < 500 行，无原生弹窗，多词不溢出。
- [x] 2.2 重构 `mobile/lib/widgets/space_anchor_bar.dart`、`mobile/lib/widgets/home_filter_sheets.dart` 与 `mobile/lib/screens/home_screen.dart`：第一行将“全部房间”改为动态下拉选择胶囊（点击弹出 `ShadSheet` 房间选择器），将分类筛选按钮 `🏷️` 移至其右侧；删除第二行房间横滑胶囊；搜索文本框拉宽紧挨右侧麦克风按钮。验证：所有修改文件行数严格 < 500 行。

## 3. 静态检查、部署与 Release 构建

- [x] 3.1 运行 `flutter analyze`、`flutter test`（分词单元测试）及 `flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation`，并部署更新后的服务端至 186 服务器。验证：`flutter analyze` 无 error，Release APK 与 186 部署均成功。
