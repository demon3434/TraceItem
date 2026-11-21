# Spec Delta

## ADDED Requirements

### Requirement: Web 端已取出物品极简图标角标
Web 端物品卡片在物品处于 `in_use` 状态时 SHALL 仅通过紧凑的纯 Lucide 图标角标标识已取出状态，不在卡片上显示“使用中”汉字文本或额外的“已用完”标签。

#### Scenario: 渲染已取出与数量为 0 的物品卡片
- **WHEN** Web 端物品网格渲染 `status` 为 `in_use` 或 `quantity` 为 `0` 的物品卡片
- **THEN** `in_use` 卡片 SHALL 仅展示紧凑的 Lucide `PackageOpen` 图标角标且优先使用 `in_use` 组封面缩略图，`quantity` 为 `0` 的卡片不得渲染额外状态标签

### Requirement: Web 端取出使用与归还收纳弹窗
Web 端 SHALL 基于 `shadcn-vue` Dialog / Sheet 组件提供取出使用登记弹窗与归还收纳弹窗，全程禁止调用浏览器原生 `alert()`、`confirm()` 或 `prompt()`。

#### Scenario: Web 端提交取出使用登记
- **WHEN** 用户在 Web 端对 `stored` 物品点击“取出使用”
- **THEN** 系统 SHALL 打开 `shadcn-vue` Dialog，只读锁定物品名称、品牌、分类、标签与数量，开放当前房屋/房间与位置备注编辑，并要求至少上传 1 张经端侧压缩的新照片后才允许提交

#### Scenario: Web 端执行归还收纳
- **WHEN** 用户在 Web 端对 `in_use` 物品点击“归还收纳”
- **THEN** 系统 SHALL 打开 `shadcn-vue` Dialog 展示原收纳位置快照与旧收纳附件，支持用户一键原位放回或修改收纳房间/位置并局部增删替换旧收纳附件

### Requirement: Web 端卡片集成数量步进、取出/归还快捷操作与归零二次确认
Web 端 SHALL 将快捷 `-1 / +1` 数量步进融合物品卡片右上角数量胶囊中，并将取出/归还（方案 A 纯图标）按钮置于卡片左上角悬浮操作胶囊的「编辑」与「删除」之间（不放入详情预览弹窗）；数量减至 `0` 时 SHALL 通过两步 `shadcn-vue` Dialog 完成二次确认删除。

#### Scenario: Web 端卡片操作与数量减至 0 触发二次确认
- **WHEN** 用户悬停物品卡片点击左上角「编辑」与「删除」之间的取出/归还图标，或在右上角数量胶囊点击 `-1` 使数量从 `1` 降至 `0`
- **THEN** 系统 SHALL 分别打开对应取出/归还 `shadcn-vue` Dialog，或在数量归零时依次弹出两次确认 Dialog；两次均确认则执行删除并用 Toast 提示，选择保留则将数量更新为 `0`

