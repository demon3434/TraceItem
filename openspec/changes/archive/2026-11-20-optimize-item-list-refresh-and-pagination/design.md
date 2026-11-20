## Context

本设计对应 `proposal.md` 中提出的双端物品清单刷新可靠性与千件级流畅浏览优化。当前代码库约束如下：
- 服务端 `GET /api/v1/items` 已完整支持 `house_id`、`room_id`、`category_id`、`page`、`page_size`（最大 500）及 `pagination.total`。
- 移动端 `pubspec.yaml` 已引入 `cached_network_image: ^3.3.1`，但卡片仍在使用裸 `Image.network`；`home_screen.dart` 当前 476 行，接近 500 行单文件红线，扩展分页状态与刷新逻辑时必须拆分子组件。
- Web 端已具备 `VirtualItemGrid.vue` 虚拟滑动窗口，但 `MainView.vue` 当前 476 行，同样接近 500 行红线，新增分页与触底逻辑需注意模块化拆分。

## Goals / Non-Goals

**Goals:**
- 移动端在少物品、空列表、多页列表全场景下 100% 稳定触发下拉刷新，并同步空间/分类元数据。
- 移动端千件物品连续下拉加载时，图片内存占用封顶（≤40MB）、已加载缩略图磁盘命中零重复下载、网格局部刷新无整页抖动、底部具备加载/重试反馈。
- Web 端彻底消除 `page_size: 500` 截断限制，实现与 `VirtualItemGrid` 协同的触底增量分页与服务端 `category_id` 过滤。

**Non-Goals:**
- 不改造 `/search` 全文检索接口的分页协议（当前保持最多 50 条 BM25 精选结果）。
- 不引入滑动窗口内存数据裁剪（即不从内存中卸载已翻页的 `Item` 文本 DTO；对于千级家庭物品库，纯文本 DTO 占用仅数 MB，瓶颈 90%+ 在图片位图缓存）。
- 不引入任何原生弹窗（`alert` / `confirm` / `prompt`）。

## Decisions

### 1. 移动端封面图片缓存：采用 `CachedNetworkImage` 替代裸 `Image.network`
- **选择**：在 `MobileItemCard` 中使用 `CachedNetworkImage`，传入 `httpHeaders: ApiService.instance.authHeaders`、`memCacheWidth: 400` 与占位/错误退避 Emoji。
- **替代方案**：复用自研 `MediaCacheManager` 手动下载再 `Image.file`。
- **理由**：`cached_network_image` 已在 `pubspec.yaml` 中就绪且原生支持 Flutter `ImageProvider` 生命周期、并发去重、磁盘缓存与 `memCacheWidth` 降采样，改造成本最低且最稳定；自研 `MediaCacheManager` 继续专注于音视频大文件与配额管控，职责清晰。

### 2. 移动端内存封顶：`main.dart` 启动时收紧全局 `ImageCache`
- **选择**：在 `main()` 中设置 `PaintingBinding.instance.imageCache.maximumSize = 150` 与 `maximumSizeBytes = 40 << 20`（40 MB）。
- **理由**：Flutter 默认允许缓存 1000 张 / 100 MB 位图，连续刷千件物品会在低内存手机上堆积至近 100 MB 才淘汰；收紧至 150 张 / 40 MB 后，屏幕外旧卡片解码位图会及时释放，配合磁盘缓存滑回时可从本地闪存毫秒级重新解码。

### 3. 移动端单文件 <500 行拆分：`HomeScreen` 网格与空状态解耦
- **选择**：将 `HomeScreen` 中的网格分页展示区（含 `RefreshIndicator`、`GridView.builder`、底部加载/重试 Sliver 或 Footer、空状态包裹）拆分为独立 Widget 文件 `mobile/lib/widgets/home_item_grid.dart`，保持 `home_screen.dart` 控制在 400 行以内。
- **并发防重入**：在 `HomeScreenState` 中维护单调递增的 `_requestEpoch`（每次重置刷新/切换筛选时自增），异步回调对比 epoch 不一致时直接丢弃旧响应。

### 4. Web 端触底增量分页：`VirtualItemGrid` 暴露底部哨兵 + `MainView` 管理分页状态
- **选择**：在 `VirtualItemGrid.vue` 底部增加 `IntersectionObserver` 哨兵（或向父组件 emit `load-more` 事件），并在底部渲染加载中 / 点击重试 / 已全部加载状态条；`MainView.vue` 改用 `pageSize = 60` 逐页追加，且在 `watch([activeHouseId, activeRoomId, selectedCategory])` 时重置 `page = 1` 并传 `category_id` 给 `getItemsApi`。
- **文件行数控制**：若 `MainView.vue`（当前 476 行）因分页逻辑接近 500 行，将分页状态与加载逻辑抽离为组合式函数 `web/src/composables/useItemPagination.ts`。

## Risks / Trade-offs

- **[Risk] 移动端切换主题或增删物品后，网格局部刷新与请求竞态导致闪烁** → **Mitigation**：为网格卡片绑定 `ValueKey(item.id)`，配合 `_requestEpoch` 丢弃过期请求。
- **[Risk] `VirtualItemGrid.vue` 底部哨兵在容器尚未出现滚动条或首次加载不足一屏时误触发** → **Mitigation**：由 `MainView` / `useItemPagination` 严格校验 `hasMore && !loading && !loadingMore` 后才发起下一页请求。
- **[Risk] 鉴权 Token 刷新后 `CachedNetworkImage` 旧缓存 Key 或 Header 失效** → **Mitigation**：`MediaCacheManager` / 图片 URL 路径本身不包含临时签名，Token 仅通过 `httpHeaders` 传递；若遇 401 退避展示分类 Emoji 占位图。

