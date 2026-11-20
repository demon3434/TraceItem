## MODIFIED Requirements

### Requirement: Spatial Cascade Deletion with Danger Confirmation
Web 端 SHALL 通过自定义 `ConfirmDialog` 进行删除前危险确认，并在房屋或房间内存在未删除物品时禁止删除且引导改为停用，严禁使用浏览器原生 `alert()`、`confirm()` 或 `prompt()`。

#### Scenario: Deleting a house invokes confirmation dialog
- **WHEN** 用户点击删除无任何物品的空房屋或空房间
- **THEN** 系统 SHALL 不得使用浏览器原生 `confirm()`，而 MUST 打开自定义 `ConfirmDialog` 进行危险确认，并在确认后调用 `DELETE /api/houses/{id}` 或 `DELETE /api/rooms/{id}` 完成删除

#### Scenario: 删除非空房屋或房间时拦截并引导停用
- **WHEN** 用户点击删除某房屋或房间，且其名下存在未删除物品（服务端返回拦截错误或前端已知存在物品）
- **THEN** 系统 SHALL 不得使用浏览器原生弹窗，而 MUST 通过自定义 `ConfirmDialog` 或自定义 Toast 明确提示不可删除的原因（含物品数量引导），并提供「停用」替代建议

## ADDED Requirements

### Requirement: Web 端房屋与房间启停控制及已停用空间开关
Web 端 SHALL 支持在空间管理侧边栏启停房屋与房间，默认隐藏已停用空间并提供显式切换开关以便随时找回历史物品，同时在物品录入表单中隐藏已停用空间。

#### Scenario: 切换房屋或房间的启用与停用状态
- **WHEN** 用户在左侧空间栏对房屋或房间执行「停用」或「启用」操作
- **THEN** Web 端 SHALL 调用对应的状态更新接口并更新本地空间状态，停用成功提示使用自定义 Toast

#### Scenario: 空间侧边栏「显示已停用空间」开关
- **WHEN** 用户在左侧空间栏查看空间列表（默认开关关闭）
- **THEN** 系统 SHALL 默认收起或隐藏已停用的房屋与房间；当用户开启「显示已停用空间」开关后，SHALL 展示已停用空间并附带清晰的「已停用」视觉标识，点击仍可筛选查看其中的历史物品

#### Scenario: 物品录入与编辑表单中的空间选项过滤
- **WHEN** 用户打开新建物品弹窗
- **THEN** 房屋与房间下拉选择器 SHALL 仅展示 `is_active == True` 的有效启用空间
- **WHEN** 用户打开编辑历史物品弹窗且该物品当前归属的空间已被停用
- **THEN** 选择器 SHALL 保留当前所属空间选项以便编辑其他信息，同时隐藏其他已停用空间
