## Context

See [proposal.md](proposal.md) for background and motivation.
当前系统后端为 FastAPI + SQLite 3 WAL，Web 端基于 Vue 3 + Tailwind + Lucide Icons，移动端基于 Flutter + `shadcn_ui`。
在实现多模态媒体预览、分类管理、共享标签和滑动窗口时，必须严格遵守全局约束：
- 单文件代码行数严格限制在 500 行以内；
- 严禁任何浏览器原生 `alert()` / `confirm()`，必须使用统一的温润大圆角自定义弹出层（`ConfirmDialog` / `ShadDialog` / `ShadSheet`）；
- 保持私有账本隔离与儿童友好多巴胺视觉设计。

## Goals / Non-Goals

**Goals:**
- 提供双端高精度媒体预览：图片手势/滚轮缩放、自研多巴胺音频播放条、大圆角沉浸式短视频播放；
- 实现 14 套居家预设分类模板库，新用户注册自动注入，支持完整的分类增删改及停用；
- 实现全库标签共享池，输入防抖联想，保存时原子去重复用；
- 建立双端虚拟滑动窗口机制，支撑上千件物品在视口中以 60fps 顺滑滚动，DOM 节点恒定 <40 个。

**Non-Goals:**
- 不引入外部庞大重量级富文本编辑器或重量级商业媒体播放器插件；
- 不允许分类跨用户共享（分类仍严格归属各自用户，仅标签共享名词池）；
- 不在数据库中建立多级深层子分类（保持扁平分类以契合儿童及老人认知）。

## Decisions

### 1. 媒体预览与缩放控制交互架构
- **Web 端**：
  - 封装独立的 `InteractiveImageViewer.vue`，基于 CSS transform (`scale`, `translate`) 监听滚轮与鼠标拖拽事件，支持 100%~400% 缩放与居中复位；
  - 封装 `DopamineAudioPlayer.vue`，使用原生 Web Audio / Audio 元素封装播放/暂停、倍速切换（1.0x / 1.5x）、波形拟态进度条，消除原生黑灰控件；
  - 视频播放器以 20px 圆角 squircle 容器包裹，自定义播放蒙层。
  - *替代方案*：引入第三方 `viewerjs` 或 `video.js`。*弃用原因*：外部库包体积臃肿、样式难以深度适配多巴胺主题。
- **Mobile 端 (Flutter)**：
  - 封装 `MediaPreviewSheet` / `MediaPreviewDialog`，图片展示包裹在 Flutter 原生 `InteractiveViewer` 内，配置 `minScale: 1.0, maxScale: 4.0`；
  - 弹窗统一使用 `ShadDialog` 承载，符合 `shadcn-ui-flutter` 规范。

### 2. 14 套居家预设分类与用户生命周期隔离
- **预设模板**：在后端 `server/app/db/constants.py` 定义 14 个居家核心分类与对应 Emoji 图腾（常备药品 💊、证件票据 📑、数码配件 🔌、五金工具 🧰、儿童玩具 🧸、办公文具 ✏️、厨房用品 🍳、食品干货 🍵、日用清洁 🧼、服饰鞋帽 👔、美妆个护 💄、运动户外 ⛺、家居家纺 🛋️、闲置收藏 📦）；
- **生命周期 Hook**：
  - 用户注册成功后，通过 `category_service.seed_user_categories(db, user_id)` 一次性批量写入当前用户的私有分类表；
  - `Category` 模型新增 `is_active: bool = True`；分类列表接口提供 `include_inactive: bool = False` 过滤；
  - 删除分类时，若存在关联物品，通过 `ConfirmDialog` 提示用户将物品的 `category_id` 置为 `NULL`（安全解绑），严禁级联删除物品。

### 3. 全局共享标签池与原子幂等去重
- **数据解耦**：
  - 调整 `tags` 表结构，`name` 设立为全表唯一索引（`UNIQUE`），移除与单一用户的强制绑定；
  - 物品与标签通过现有 `item_tags` 关联表映射，每个用户的物品仅保存与全局标签主键的对应关系；
- **补全联想 API**：
  - 暴露 `GET /api/tags/suggest?q={prefix}&limit=8`，采用 SQL `WHERE name LIKE :pattern` 进行索引前缀检索；
- **原子保存逻辑**：
  - `resolve_tags` 服务层对输入的标签字符串进行 `strip()` 去除空白；
  - 查询数据库 `db.query(Tag).filter(Tag.name == clean_name).first()`，若存在则复用主键 `tag.id`，若不存在则创建新记录，完全消除同名冗余数据。

### 4. 双端虚拟滑动窗口 (Virtual Grid Windowing) 与内存防护
- **Web 端虚拟网格**：
  - 封装 `VirtualItemGrid.vue`：
    - 根据容器宽度动态计算列数（$C \in [1, 5]$）与固定行高（$H = 340px$）；
    - 监听父级滚动容器的 `scrollTop`，动态推导当前视口可见的起始行 $R_{start} = \max(0, \lfloor \text{scrollTop} / H \rfloor - 1)$ 和结束行 $R_{end} = R_{start} + \lceil \text{viewportHeight} / H \rceil + 2$；
    - 动态计算顶部占位高度 $P_{top} = R_{start} \times H$ 与底部占位高度 $P_{bottom} = (\text{totalRows} - R_{end}) \times H$；
    - 视口内仅渲染切片数据 `items.slice(R_start * C, R_end * C)`，DOM 节点数量恒定保持在 30 个以内。
- **Android (Flutter) 端**：
  - `GridView.builder` 原生具备可视区域 Widget 销毁与复用机制；
  - 绑定 `ScrollController`，当 `position.pixels >= position.maxScrollExtent - 300` 时触发下一页数据追加；
  - `MobileItemCard` 网格卡片一律优先绑定 320px 缩略图路径（`thumbnail_url`），并在 `Image.network` 中配置 `cacheWidth: 400`，彻底防止 1600px 原图占满显存引起 GC 掉帧。

## Risks / Trade-offs

- **[Risk] 旧数据库存量 `categories` 与 `tags` 表迁移冲突**  
  → **Mitigation**: 在数据库初始化脚本与 Alembic/Base 检查中，检测 SQLite 列名是否存在 `is_active`，若缺失则通过 `ALTER TABLE categories ADD COLUMN is_active BOOLEAN DEFAULT 1` 无缝原地兼容升级；针对 `tags` 表中原有的同名数据，执行一次分组归并脚本，合并同名标签至最小 ID 并更新 `item_tags` 映射。
- **[Risk] 虚拟网格窗口在屏幕尺寸快速拉伸（Resize）时发生重叠计算**  
  → **Mitigation**: 使用 `ResizeObserver` 监听网格容器宽度，采用 `requestAnimationFrame` 防抖更新列数与行高，保证布局始终无缝响应。
- **[Risk] 移动端网络不稳定时连续触发触底翻页**  
  → **Mitigation**: 移动端维护 `_isLoadingMore` 标志位防重入互斥锁，并在翻页出错时提供温润轻量 Toast 重试引导。

## Migration Plan

1. 执行数据库结构兼容升级：
   - 为 `categories` 增加 `is_active` 字段；
   - 整理现有 `tags` 重复数据，保证 `name` 全局唯一；
2. 升级后端 API 与 Service（分类 CRUD、模板克隆、标签联想与去重）；
3. 改造 Web 端：实现交互式多媒体预览弹窗与虚拟滑动窗口网格；
4. 改造 Android 端：实现详情预览弹窗与 `GridView.builder` 增量触底加载。

