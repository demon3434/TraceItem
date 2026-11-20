---
name: ui-typography-and-theming
description: "按图索骥 (TraceItem) 全端 UI 排版字号与多巴胺主题切换规范。用于所有 Web (Vue 3 + Tailwind) 与 Mobile (Flutter + shadcn_ui) 页面、组件开发与审查，确保字号舒适清晰、严禁过小字体，并统一支持 5 套多巴胺主题一键切换。"
---

# TraceItem UI 排版字号与多巴胺主题规范

本文档为“按图索骥”全端界面的字号与主题硬性规范。所有 Agent 与人类开发者在编写或修改 UI 组件时必须无条件遵守。

---

## 📏 1. 字体字号可读性硬性标准 (Typography Standards)

> [!IMPORTANT]
> **严禁“眯眯眼”极小字号**：
> 任何页面绝对禁止使用 `text-[10px]` 或 `<12px` 的极小字号。所有文字必须在桌面高分辨率大屏和各类设备上达到无需辨认的清晰可读性。

### 阶梯字号映射表 (Tailwind / CSS)
- **品牌 Logo / 大屏主标题**：`text-xl` ~ `text-2xl` (20px ~ 24px)，`font-black` 或 `font-bold`；
- **弹窗标题 / 空间区块大标题**：`text-lg` (18px)，`font-bold`；
- **物品卡片标题 / 房屋主节点**：`text-base` (16px)，`font-bold`，`leading-snug`；
- **标准正文 / 表单输入框 / 下拉框 / 房间子节点 / 搜索框**：`text-sm` ~ `text-base` (14px ~ 15px)；
- **辅助说明 / 标签气泡 / 规格型号 / 极小徽章**：`text-xs` (12px)，`font-semibold` 或 `font-medium`；
- **禁止项**：严禁出现 `text-[10px]`、`text-[11px]`、`font-size: 10px`。

---

## 🎨 2. 五套多巴胺活力主题与 CSS 变量规范

系统内置 5 套活力多巴胺主题，统一通过 CSS 变量与 Pinia Theme Store 驱动：

1. **阳光暖橙 (warm-orange, 默认)**：
   - Primary: `#f97316` (Orange-500)
   - Secondary / Light: `#fff7ed` (Orange-50), `#ffedd5` (Orange-100)
   - Dark Text: `#9a3412` (Orange-800)
   - Background: `#FAF9F6`
2. **草莓甜心 (strawberry-sweet)**：
   - Primary: `#f43f5e` (Rose-500)
   - Secondary / Light: `#fff1f2` (Rose-50), `#ffe4e6` (Rose-100)
   - Dark Text: `#9f1239` (Rose-800)
   - Background: `#FFF5F6`
3. **薄荷清柠 (mint-lemon)**：
   - Primary: `#10b981` (Emerald-500)
   - Secondary / Light: `#f0fdf4` (Emerald-50), `#d1fae5` (Emerald-100)
   - Dark Text: `#065f46` (Emerald-800)
   - Background: `#F4FBF7`
4. **星空城堡 (starry-castle)**：
   - Primary: `#6366f1` (Indigo-500)
   - Secondary / Light: `#eef2ff` (Indigo-50), `#e0e7ff` (Indigo-100)
   - Dark Text: `#3730a3` (Indigo-800)
   - Background: `#F6F8FD`
5. **雅致原木 (elegant-wood)**：
   - Primary: `#b45309` (Amber-700)
   - Secondary / Light: `#fef3c7` (Amber-100), `#fde68a` (Amber-200)
   - Dark Text: `#78350f` (Amber-900)
   - Background: `#F9F8F6`

---

## 🧩 3. 主题切换机制实现原则
- 存储：切换主题后自动保存至本地持久化 `localStorage.getItem('traceitem_theme')`；
- DOM 标记：在根节点挂载 `data-theme="<theme-id>"`，并通过 CSS 变量 `--theme-primary`、`--theme-bg` 全局生效；
- 组件适配：按钮、激活状态、高亮光晕、输入框聚焦光圈均统一绑定主题主色，禁止硬编码死单色。

