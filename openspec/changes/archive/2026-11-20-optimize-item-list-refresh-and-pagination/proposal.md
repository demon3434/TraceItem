## Why

当前双端物品清单在高频浏览与大数量场景下存在明显体验缺陷：
1. **移动端下拉刷新时灵时不灵**：物品较少（未满一屏）或空列表状态下，`GridView.builder` 不可滚动且空状态外层缺少 `RefreshIndicator`，导致无法触发下拉刷新；且刷新仅拉取第 1 页物品而未同步更新空间与分类元数据。
2. **移动端千件物品滑动卡顿与内存隐患**：卡片封面使用裸 `Image.network`，缺少磁盘缓存（滑回重复下载解码），且未收紧 Flutter 全局 `ImageCache` 内存上限（默认高达 100MB/1000张）；同时触底加载缺乏底部加载态与失败重试反馈，翻页 `setState` 会触发整页重建。
3. **Web 端 500 条截断与前端过滤盲区**：`MainView.vue` 写死 `page: 1, page_size: 500` 一次性拉取，导致第 501 件起的数据完全不可见，且分类筛选仅在前端对前 500 条进行过滤。

## What Changes

- **移动端全场景下拉刷新修复**：
  - 为 `GridView.builder` 与空状态 `HomeEmptyState` 滚动容器统一配置 `AlwaysScrollableScrollPhysics()`，并在空状态外层同样包裹 `RefreshIndicator`。
  - 下拉刷新时同步更新房屋、房间、分类快照与第 1 页物品，并引入请求序号防竞态/防重入机制。
- **移动端千件流畅滚动与内存封顶优化**：
  - 将 `MobileItemCard` 封面图由裸 `Image.network` 升级为 `CachedNetworkImage`（配合 `memCacheWidth: 400` 与鉴权 Header），实现内存+磁盘双级缓存，滑回零网络开销。
  - 在 `main.dart` 启动阶段收紧 `PaintingBinding.instance.imageCache` 上限（如 `maximumSize = 150`、`maximumSizeBytes = 40MB`），防止无限下滑时图片内存持续膨胀。
  - 为 `GridView.builder` 项补齐稳定 `ValueKey(item.id)` 及合理的 `cacheExtent`，将网格区域状态与顶栏隔离，并在网格底部增加「正在加载更多 / 加载失败点击重试 / 已加载全部」状态指示器。
- **Web 端触底增量分页与服务端分类过滤**：
  - 取消 `MainView.vue` 中写死的 `page_size: 500`，改为每页 `60` 条的后端分页加载，配合 `VirtualItemGrid` 的滚动容器触底监听自动加载下一页。
  - 将分类筛选 `category_id` 传给后端 `/items` 接口，确保上千件物品中任意分类均可完整检索；补充列表底部加载状态与手动刷新入口。
- **交互与 UI 合规声明**：
  - 双端所有错误提示、刷新反馈与确认交互均严格使用统一设计体系组件（移动端 `CustomDialogs.showToast` / `ShadToaster` / `ShadDialog` / `ShadSheet`；Web 端 `toastStore` / `ConfirmDialog`），零原生 `alert()` / `confirm()` / `prompt()`。

## Capabilities

### New Capabilities

（无新增独立能力，均属于既有移动端与 Web 端核心浏览能力的增强）

### Modified Capabilities

- `mobile-media-and-performance`: 增强移动端物品清单的全场景下拉刷新（含少物品与空状态）、`CachedNetworkImage` 磁盘与内存双级缩略图缓存、收紧 `ImageCache` 内存上限、稳定 `Key` 与分页加载状态反馈。
- `web-core-experience`: 将 Web 端物品清单由单次写死 `page_size=500` 升级为配合虚拟网格的触底增量分页加载，并将分类筛选下沉至后端 `/items` 接口查询。

## Impact

- **移动端 (`mobile/`)**：`lib/main.dart`、`lib/screens/home_screen.dart`、`lib/widgets/item_card.dart`、`lib/widgets/home_empty_state.dart`（如超出或接近 500 行则拆分独立分页网格组件）。
- **Web 端 (`web/`)**：`src/views/MainView.vue`、`src/components/item/VirtualItemGrid.vue`、`src/api/index.ts`（如有需要补充 `category_id` 参数传递）。
- **服务端 (`server/`)**：`GET /api/v1/items` 已原生支持 `house_id`、`room_id`、`category_id`、`page`、`page_size`，无需破坏性变更。

