## MODIFIED Requirements

### Requirement: Interactive Mobile Media Preview Layer
移动端 SHALL 提供独立全屏物品详情页面（`ItemDetailScreen`），采用 `shadcn_ui` 对话框/抽屉范式与 `InteractiveViewer` 手势交互，取代原先局促的居中预览弹窗。

#### Scenario: User pinches to zoom photo
- **WHEN** 用户点击物品卡片进入全屏 `ItemDetailScreen` 查看照片
- **THEN** 应用 SHALL 支持多张照片切换浏览，并允许在 1.0x 至 4.0x 倍率间双指捏合缩放、双击在 1.0x 与 2.5x 间切换及拖拽平移细节

#### Scenario: User plays audio guide or video guide
- **WHEN** 物品包含语音备忘或寻路短视频附件
- **THEN** `ItemDetailScreen` SHALL 渲染符合当前多巴胺主题的音视频播放器组件，支持播放、暂停、进度条拖拽与时长展示

#### Scenario: 在详情页直接执行编辑与危险删除
- **WHEN** 用户在 `ItemDetailScreen` 浏览物品详情
- **THEN** 页面底部常驻操作栏 SHALL 提供「编辑信息」（跳转至 `ItemEditScreen`）与「删除物品」（弹出危险态 `ShadDialog` 二次确认后调用 `DELETE /api/items/{id}`）

## ADDED Requirements

### Requirement: 全模态物品创建与编辑能力对齐
移动端物品录入与编辑页 `ItemEditScreen` SHALL 补齐与 Web 端普通成员一致的全量表单字段与媒体能力，严格执行 `>= 12px` 字号与 `ShadToaster` 反馈规范。

#### Scenario: 录入或修改分类、多图、短视频、语音与联想标签
- **WHEN** 用户在 `ItemEditScreen` 新增或编辑物品
- **THEN** 用户 SHALL 可选择所属房屋与房间（支持继承空间锚定）、选择启用中的物品分类、上传或移除多张端侧压缩图片、拍摄或选取最长 15 秒的现场短视频、录制最长 60 秒语音备忘录，并在输入标签时通过 `GET /api/items/tags/suggest` 获取前缀联想建议

### Requirement: 随激活线路动态解析多媒体地址
移动端 SHALL 基于路由管理器当前生效的服务器 Base URL 动态拼接所有图片、缩略图、音频与视频访问路径。

#### Scenario: 内外网切换后媒体资源正常加载
- **WHEN** 当前激活线路在内网地址与外网地址之间切换（或用户修改自定义服务器地址）
- **THEN** 物品卡片缩略图与 `ItemDetailScreen` 多媒体播放器 SHALL 统一使用动态解析的绝对 URL 加载资源，不再使用硬编码默认地址
