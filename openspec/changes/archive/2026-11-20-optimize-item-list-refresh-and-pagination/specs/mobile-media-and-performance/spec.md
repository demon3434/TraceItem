## MODIFIED Requirements

### Requirement: Mobile Windowed Item Grid and Memory Bounds
移动端 SHALL 通过懒加载窗口网格（`GridView.builder`）渲染物品清单，在滚动接近底部阈值时异步增量拉取下一页，并对缩略图解码、磁盘持久化缓存与全局内存图片池实施严格上限控制，确保千件以上物品连续下滑不卡顿、不产生内存膨胀。

#### Scenario: Seamless incremental pagination on scroll
- **WHEN** 用户向下滑动列表至距离当前列表底部 300 像素以内且仍有更多数据时
- **THEN** 移动端 SHALL 异步请求下一页物品并无闪烁地追加至列表，同时在网格底部展示加载中指示器；若网络请求失败，SHALL 展示可点击重试的轻量提示而不静默丢失翻页机会

#### Scenario: Memory-bounded thumbnail decoding
- **WHEN** 物品网格渲染卡片封面图时
- **THEN** 移动端 SHALL 优先加载服务端生成的 320px `thumbnail_url`（配合 `memCacheWidth: 400` 限制解码分辨率与请求鉴权 Header），并通过磁盘缓存实现滑出再滑回时的零网络重复下载；同时应用启动阶段 SHALL 将全局 `ImageCache` 上限收紧至合理范围（如最多 150 张、40MB），避免连续加载多轮后位图内存持续攀升

#### Scenario: 稳定卡片标识与局部重建隔离
- **WHEN** 列表触发下拉刷新、增删改或追加分页数据时
- **THEN** 网格项 SHALL 绑定稳定的 `ValueKey(item.id)`（并配合索引回调），且翻页与列表刷新 SHALL 仅局部重绘列表区域而不连带重建顶部空间栏与搜索栏

## ADDED Requirements

### Requirement: 移动端物品清单全场景下拉刷新
移动端物品清单首页 SHALL 在任意数据量状态下（包括物品不足一屏、空列表以及多页列表）均稳定支持下拉刷新手势，并同步更新空间/分类元数据与第 1 页物品，同时防止并发请求竞态。

#### Scenario: 少数物品（不足一屏）触发下拉刷新
- **WHEN** 当前房间仅有少量物品、网格内容高度小于可视区域高度时用户执行下拉手势
- **THEN** 列表滚动容器 SHALL 启用始终可滚动物理特性（`AlwaysScrollableScrollPhysics`），成功触发 `RefreshIndicator` 并拉取最新数据

#### Scenario: 空列表状态触发下拉刷新
- **WHEN** 当前空间或筛选条件下物品为空（展示空状态引导页）时用户执行下拉手势
- **THEN** 空状态滚动容器外层 SHALL 同样包裹 `RefreshIndicator` 并允许下拉，拉取到新数据后立即切换展示物品网格

#### Scenario: 刷新同步元数据与并发防重入
- **WHEN** 用户触发下拉刷新时
- **THEN** 客户端 SHALL 同步拉取最新的房屋、房间、分类快照与第 1 页物品，并通过请求序号或锁机制丢弃过期/被覆盖的旧响应；失败时通过统一轻提示气泡（`CustomDialogs.showToast`）反馈，严禁使用原生弹窗
