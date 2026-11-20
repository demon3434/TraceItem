## 1. 数据库模型演进与预设模板 (Backend Models & Category Template)

- [x] 1.1 在 `server/app/models/item.py` 为 `Category` 模型添加 `is_active: Mapped[bool] = mapped_column(Boolean, default=True)` 字段，并将 `Tag` 模型的唯一约束调整为全局 `name` 唯一，运行初始化脚本验证表结构生成无报错
- [x] 1.2 在 `server/app/db/constants.py` 定义 14 种居家日常预设分类常量与 Emoji 图腾，并在 `server/app/services/category_service.py` 编写 `seed_user_default_categories(db, user_id)` 函数，通过单元测试验证克隆注入正确
- [x] 1.3 在 `server/app/api/auth.py` 新用户注册成功后调用预设分类注入函数，执行测试验证新注册账号自动持有 14 套私有分类

## 2. 分类与共享标签后端接口升级 (Backend Categories & Tags APIs)

- [x] 2.1 在 `server/app/api/items.py` 补充完善分类管理接口（`PUT /categories/{id}`、`DELETE /categories/{id}`、`PATCH /categories/{id}/status`），增加关联物品安全解绑检查（置空 `category_id`），编写测试验证分类增删改停用
- [x] 2.2 新增 `GET /api/tags/suggest?q={prefix}` 实时前缀检索端点，并在 `server/app/services/item_service.py` 的 `resolve_tags` 中实现全局原子复用，测试验证盲打同名标签不产生重复记录
- [x] 2.3 优化 `GET /api/items` 接口，支持标准分页切片与精确总数元数据返回，确保高吞吐量下查询轻量快速

## 3. Web 端高精媒体预览与多巴胺播放组件 (Web Media Preview & Players)

- [x] 3.1 拆分创建 `web/src/components/item/InteractiveImageViewer.vue`，实现鼠标滚轮平滑缩放（100%~400%）、鼠标按住拖拽平移与悬浮复位胶囊，在预览弹窗中验证大图操作流畅
- [x] 3.2 封装 `web/src/components/item/DopamineAudioPlayer.vue` 与圆角视频播放容器，提供声波拟态动效、进度滑块、1.0x/1.5x 倍速切换与温润大圆角蒙层，验证彻底杜绝原生媒体条
- [x] 3.3 升级 `web/src/components/item/MediaPreviewDialog.vue`，集成上述组件并确保单文件行数严格在 300 行以内

## 4. Web 端分类管理与标签补全 (Web Categories & Tag Autocomplete)

- [x] 4.1 封装 `web/src/components/item/CategoryManageDialog.vue` 分类管理弹窗抽屉，支持分类增删改查、排序、停用/激活与删除解绑确认（使用 `ConfirmDialog`），验证零原生 alert
- [x] 4.2 封装 `web/src/components/item/TagInputAutocomplete.vue` 气泡联想输入组件，实现 200ms 防抖请求建议并支持键盘选择，并在 `ItemDialog.vue` 中集成

## 5. Web 端上千物品虚拟滑动窗口 (Web Virtual Grid Windowing)

- [x] 5.1 封装 `web/src/components/item/VirtualItemGrid.vue`，根据视口高度与滚动偏移量仅渲染可视窗口与上下缓冲区内的行，外层占位 padding 维持滚动条物理尺寸，验证千条数据 DOM 节点恒定 <40 个且 60fps 滚动
- [x] 5.2 在 `web/src/views/MainView.vue` 中接入 `VirtualItemGrid.vue`，替换原有全量 `v-for`，对接分类筛选与增量翻页

## 6. Android (Flutter) 端媒体预览与滑动窗口 (Mobile Media & Virtual Windowing)

- [x] 6.1 在 `mobile/lib/widgets/media_preview_dialog.dart` 中基于 `InteractiveViewer` 与 `shadcn_ui` 实现大图双指缩放、双击还原与音视频播放浮层，并在 `MobileItemCard` 点击回调中触发弹窗
- [x] 6.2 在 `mobile/lib/screens/home_screen.dart` 中为 `GridView.builder` 配置 `ScrollController` 触底 300px 自动拉取下一页，并为网格卡片配置 320px 缩略图与 `cacheWidth: 400` 显存上限，验证垂直滚动流畅无掉帧
- [x] 6.3 封装 `mobile/lib/widgets/category_manage_sheet.dart` 分类管理底部抽屉（基于 `ShadSheet`），支持分类增删改停用并接入主页分类滑轨

## 7. 全链路回归与约束审计 (Full-Stack Verification & Constraint Audit)

- [x] 7.1 运行全栈测试套件（后端 pytest、Web 端构建、移动端静态检查），验证所有新增接口与功能无报错
- [x] 7.2 审查所有新增与修改的代码文件行数，确认每个文件严格小于 500 行，且代码中 100% 杜绝 `window.alert` / `window.confirm` / `prompt`

