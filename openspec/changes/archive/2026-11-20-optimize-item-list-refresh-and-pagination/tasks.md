## 1. 移动端全局图片内存池与卡片双级缓存优化

- [x] 1.1 在 `mobile/lib/main.dart` 启动流程中收紧全局 `PaintingBinding.instance.imageCache` 上限（`maximumSize = 150`、`maximumSizeBytes = 40 << 20`），验证应用启动无异常且单文件行数 <500 行
- [x] 1.2 改造 `mobile/lib/widgets/item_card.dart`，将裸 `Image.network` 替换为 `CachedNetworkImage`（配置 `httpHeaders: ApiService.instance.authHeaders`、`memCacheWidth: 400`、主题占位底色与分类 Emoji 退避渲染），验证滑出再滑回时命中磁盘缓存且单文件行数 <500 行

## 2. 移动端全场景下拉刷新与分页状态解耦

- [x] 2.1 新建独立网格组件 `mobile/lib/widgets/home_item_grid.dart`（控制 <300 行），使用 `RefreshIndicator` 同时包裹空状态与 `GridView.builder`，统一配置 `AlwaysScrollableScrollPhysics()`，为卡片绑定 `ValueKey(item.id)` 及合理的 `cacheExtent`
- [x] 2.2 在 `mobile/lib/widgets/home_item_grid.dart` 底部增加分页状态尾行（使用主题主色展示「正在加载更多」、加载失败时展示可点击重试按钮及「已加载全部」提示），确保字号 ≥12px 且符合多巴胺主题令牌
- [x] 2.3 改造 `mobile/lib/screens/home_screen.dart` 与 `mobile/lib/widgets/home_empty_state.dart`：下拉刷新统一调用 `loadInitialData(keepSelection: true)` 同步空间/分类元数据与第 1 页物品；引入 `_requestEpoch` 防竞态并发覆盖；`_loadMoreItems()` 暴露 `isLoadingMore` 与 `loadMoreError` 状态供 `HomeItemGrid` 局部展示，异常提示统一使用 `CustomDialogs.showToast`（零原生弹窗），并确认各文件行数均 <500 行

## 3. Web 端触底增量分页与服务端分类过滤

- [x] 3.1 检查 `web/src/api/index.ts` 中 `getItemsApi` 参数定义，确保支持传入 `category_id`、`page`、`page_size` 并返回完整 `pagination` 元信息
- [x] 3.2 抽离分页组合式逻辑至 `web/src/composables/useItemPagination.ts`（控制 <200 行），以 `pageSize = 60` 管理增量拉取、`hasMore`、`loadingMore`、`loadMoreError` 及请求序号防重入，并在切换房屋、房间或分类时重置至第 1 页重新请求后端
- [x] 3.3 改造 `web/src/components/item/VirtualItemGrid.vue` 增加底部 `IntersectionObserver` 哨兵触发 `load-more` 事件，并渲染主题化底部加载中/重试/已加载全部提示条（字号 ≥12px）
- [x] 3.4 更新 `web/src/views/MainView.vue` 接入 `useItemPagination` 与手动刷新按钮，移除写死的 `page_size: 500` 与纯前端分类过滤，错误反馈统一使用 `toastStore`（零原生 `alert`/`confirm`），并验证所有修改文件行数 <500 行

## 4. 跨端验证与代码合规检查

- [x] 4.1 运行移动端静态分析与测试（`flutter analyze` 与 `flutter test`），确认无语法错误及告警
- [x] 4.2 运行 Web 端类型检查与构建（`npm run build` 或 `vue-tsc --noEmit`），确认 TypeScript 类型与组件引用全部通过
- [x] 4.3 核对所有新增与修改的 `.dart`、`.vue`、`.ts` 文件行数均严格 <500 行，且无任何原生 `alert`/`confirm`/`prompt` 调用
