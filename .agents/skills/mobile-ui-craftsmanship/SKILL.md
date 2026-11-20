---
name: mobile-ui-craftsmanship
description: "按图索骥 (TraceItem) 移动端 (Flutter) 旗舰级 UI 美学、微交互与触感工艺设计规范。用于提升 Android/iOS 客户端界面美观度、呼吸感、多巴胺活力材质与儿童友好体验，彻底消除工程师原型感。"
---

# TraceItem 移动端旗舰级 UI 美学与工艺规范 (Mobile UI Craftsmanship)

本文档定义了“按图索骥”移动端（Flutter / Android / iOS）的高端 UI 美学、视觉质感与微交互规范。所有客户端页面与组件的开发、重构均必须严格遵循本规范。

---

## 💎 1. 核心视觉设计语言 (Visual Design System)

### 1.1 材质、光影与呼吸感 (Elevation & Ambient Shadows)
- **拒绝生硬阴影与纯黑实线**：严禁使用 `Colors.black` 或大透明度硬边框。
- **漫反射双层柔和投影 (Ambient Double Shadow)**：
  卡片与悬浮层采用模拟真实环境光的柔和微光投影：
  ```dart
  boxShadow: [
    BoxShadow(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ]
  ```
- **温润 Squircle 圆角阶梯**：
  - 外层大卡片 / 底部半屏抽屉：`BorderRadius.circular(24)`
  - 内部模块 / 物品缩略图 / 输入框：`BorderRadius.circular(16)` ~ `18`
  - 药丸徽章 / 胶囊按钮：`BorderRadius.circular(999)`

### 1.2 多巴胺活力层次与背景质感 (Dopamine Color Layering)
- **背景拒绝单调惨白**：页面底色采用轻微带有温度的米白/奶彩底色（如 `#FAF9F6`），搭配局部高光渐变。
- **渐变点缀与焦点强化**：重要操作按钮与统计胶囊支持 Subtle Gradient（从 `primary` 到轻微偏暖/明亮色），增加流动感与品质感。
- **毛玻璃悬浮效果 (Frosted Glass / BackdropFilter)**：
  顶部导航栏与悬浮操作条推荐使用半透明毛玻璃背景 (`ImageFilter.blur(sigmaX: 12, sigmaY: 12)`)，营造现代沉浸感。

---

## ⚡ 2. 微交互与触感反馈 (Tactile & Micro-Interactions)

### 2.1 触觉反馈 (Haptic Feedback)
在所有核心用户操作中嵌入适度轻微的触觉震动反馈，赋予实体按压感：
- 点击重要卡片、切换房间胶囊：`HapticFeedback.lightImpact()`
- 长按语音寻物、触发录音：`HapticFeedback.mediumImpact()`
- 成功保存/新增物品：`HapticFeedback.heavyImpact()` 或 `vibrate()`

### 2.2 按压微缩弹性动画 (Scale-on-Press Delight)
为可交互卡片与重要按钮提供轻盈的手势缩放响应：
- 按下时轻微缩小至 `0.97` ~ `0.98`
- 松开时平滑弹回 `1.0`
- 搭配平滑贝塞尔曲线（如 `Curves.easeOutCubic`，时长 120ms~180ms）

### 2.3 列表与页面入场微动效 (Staggered Entrance)
- 物品卡片进入视窗时，避免突兀瞬间闪现；
- 采用轻微上滑淡入动效（`fade + slideY`），节奏轻快（200ms~300ms）。

---

## 🧸 3. 儿童与家庭友好设计 (Kid & Family Friendly)

1. **超大触控热区**：所有可点击控件热区不小于 `48 × 48 dp`，边缘附带至少 8dp padding。
2. **生动趣味图腾 (Emoji & Pictograms)**：每个空间、每个分类均前置鲜活的大 Emoji（🧸、🛋️、🚀、📚），即使儿童不识字也能秒认位置。
3. **空状态趣味插画 (Empty States with Personality)**：当房间无物品或搜索无结果时，展示大图标表情与温暖可爱的趣味文案（如“这里空空如也，快把你的宝贝收纳进来吧~”），并直接附带【+ 记一笔】快速引导按钮。
4. **字号坚守红线**：
   - 严禁低于 12px 的文字；
   - 关键标签与描述采用 13px~15px，标题 16px~22px，字重搭配清晰（`FontWeight.w700` 与 `FontWeight.w500`）。

---

## 📋 4. 代码自检清单 (Checklist)

- [ ] 单源文件严格保持在 `<500 行`，复杂动效/卡片独立抽离为 Widget；
- [ ] 杜绝任何原生 `alert/confirm`；
- [ ] 所有卡片是否具备漫反射双层柔和阴影与温润 Squircle 圆角；
- [ ] 关键交互是否加入触觉震动反馈（`HapticFeedback`）；
- [ ] 顶部导航与状态栏是否通透、是否具备呼吸感；
- [ ] 半屏抽屉必须使用 `CustomDialogs.showModalSheet`，外层安全区隔离防穿透系统状态栏；
- [ ] 抽屉内表单输入项需预留水平 breathing room，杜绝输入法激活时输入框边框被剪裁；
- [ ] 统一 Toast 消息展示于屏幕底部，停留时长控制在 1.2s~1.5s，不得遮挡控件交互；
- [ ] 整体视觉是否符合五大多巴胺活力主题标准。

