# 0002: 采用 Monorepo 组织架构，移动端使用 Flutter，桌面 Web 端使用 Vue 3

## 上下文与决策背景
原有项目存在严重的工程割裂：
- `WhereIsIt-Android`（在线）与 `WhereIsIt-Android-Offline`（离线）各自为政，Kotlin Compose 逻辑大量重复却功能参差不齐。
- 完全缺失 iOS 客户端，苹果手机用户无法使用。
- 服务端 Web 前端为早期的 Jinja2 服务端渲染外挂近 10 万行的原生单体 JavaScript（`app-core.js`），难以在大屏管理端提供现代流畅的组件化交互。

经决策，工程整合为单一的大项目代码仓库（Monorepo），移动端选用 **Flutter 3.x** 跨平台框架实现 iOS/Android 95%+ 代码复用；Web 端采用独立的 **Vue 3 + Tailwind CSS** 现代轻量 SPA。

## 架构决策与选型理由
1. **Flutter 移动端跨平台核心优势**：
   - 彻底消灭 Android 与 iOS 的多端维护成本，一套 Dart 代码编译双端，UI 像素级一致。
   - 拥有最成熟的端侧底层音视频与相机硬件操控插件生态（`camera`、`flutter_image_compress`、`record`、`video_compress`），无平台间桥接性能瓶颈。
2. **Web 端解耦选用 Vue 3**：
   - 不采用 Flutter Web 编译方案，原因是 Flutter Web 的 CanvasKit 包体积较大、首屏加载慢，且在桌面浏览器上的选中文本、键鼠快捷键与右键菜单表现不如原生 DOM。
   - 采用 Vue 3 + Tailwind CSS，配合统一的 OpenAPI/RESTful 接口，打造轻量、毫秒级首屏加载的大屏批量收纳看板。

## 用户补充细节
> **专栏：用户针对该项提出的补充与扩展**
- **统一软件命名**：项目对外统一中文品牌名称正式定名为**“图觅”**。
- **大项目一体化管理**：服务端 API、Web 端、iOS 与 Android 客户端必须集中在同一个工程中（Monorepo），消除原有的 4 个分散仓库。
- **跨平台最大化复用**：手机端代码必须尽可能跨平台复用，杜绝出现 Android 维护一套业务逻辑、iOS 再单独写一套原生逻辑的分裂局面。

