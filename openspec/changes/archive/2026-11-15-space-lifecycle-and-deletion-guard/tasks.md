# Tasks

## 1. 服务端数据模型、迁移与接口校验

- [x] 1.1 在 `server/app/models/space.py` 为 `House` 与 `Room` 新增 `is_active` 字段（默认 `True`、带索引），并在 `server/app/db/init_db.py` 补充 `houses` / `rooms` 表 `is_active` 列的兼容性 `ALTER TABLE` 迁移逻辑
- [x] 1.2 更新 `server/app/schemas/space.py`，在 `HouseUpdate`、`HouseOut`、`RoomUpdate`、`RoomOut` 中增加 `is_active` 字段
- [x] 1.3 更新 `server/app/services/space_service.py` 与 `server/app/api/houses.py`、`server/app/api/rooms.py`：实现 `PATCH /api/houses/{house_id}/status` 与 `PATCH /api/rooms/{room_id}/status`；在 `create_user_room` 校验所属房屋必须 `is_active == True`；在 `delete_user_room` 与 `delete_user_house` 实现未删除物品计数非空拦截（有物品禁止删除并提示停用，空房屋允许连带软删除空房间）
- [x] 1.4 更新 `server/app/services/item_service.py`：在 `create_user_item` 校验目标房屋与房间均 `is_deleted == False` 且 `is_active == True`；在 `update_user_item` 校验当物品变更空间位置时目标房屋与房间均有效启用，未变更位置时允许在原停用空间内保存属性修改
- [x] 1.5 为上述删除拦截、启停接口与写入校验补充后端单元测试并运行通过

## 2. Web 端空间启停、删除拦截与筛选开关

- [x] 2.1 更新 `web/src/types/` 与 `web/src/api/index.ts`，为 `House` / `Room` 类型补充 `is_active` 字段并新增 `toggleHouseStatusApi`、`toggleRoomStatusApi`
- [x] 2.2 更新 `web/src/components/space/HouseRoomSidebar.vue`、`SpaceTreeNav.vue`、`SpaceTreeRoomList.vue`：增加「显示已停用空间」开关（默认关闭），为房屋/房间节点增加「停用/启用」操作及「已停用」柔和视觉徽章（严格控制单文件 <500 行，使用自定义 Toast 反馈）
- [x] 2.3 更新 `web/src/views/MainView.vue` 的删除处理逻辑：当删除非空房屋或房间被后端拦截时，通过自定义 `ConfirmDialog` / Toast 明确提示原因并引导改为停用，严禁使用浏览器原生 `alert`/`confirm`
- [x] 2.4 更新 `web/src/components/item/ItemDialog.vue` 空间选择器：新建物品时过滤仅展示 `house.is_active && room.is_active` 的启用空间；编辑已有物品时保留其当前所在停用空间选项，隐藏其他已停用空间

## 3. 移动端空间启停、删除拦截与筛选开关

- [x] 3.1 更新 `mobile/lib/models/models.dart`（为 `House`、`Room` 新增 `isActive`）与 `mobile/lib/core/api_service.dart`（新增 `toggleHouseStatus`、`toggleRoomStatus`）
- [x] 3.2 更新 `mobile/lib/widgets/space_action_sheet.dart`、`space_manage_cards.dart` 与 `mobile/lib/screens/space_manage_screen.dart`：在 `ShadSheet` 操作抽屉内新增「停用/启用此房屋或房间」大热区选项，在卡片展示「已停用」柔和药丸徽章（遵守行内最多 1 个操作按钮与单文件 <500 行约束），并在删除非空空间被拦截时通过 `CustomDialogs.showConfirm`（`ShadDialog`）或 Toast 引导停用
- [x] 3.3 更新 `mobile/lib/widgets/home_filter_sheets.dart` 及首页空间筛选状态：新增「显示已停用空间」开关（默认隐藏已停用空间），开启后可点击查看已停用空间内的历史物品
- [x] 3.4 更新 `mobile/lib/widgets/item_edit_pickers.dart` 与 `mobile/lib/screens/item_edit_screen.dart`：新建物品时仅展示有效启用空间；编辑旧物品时保留当前所处停用空间选项，隐藏其他已停用空间

## 4. 全端校验、部署与构建交付

- [x] 4.1 核查所有新增与修改的 `.py`、`.vue`、`.ts`、`.dart` 文件行数均严格 `< 500` 行，且无原生 `alert`/`confirm`/`prompt` 调用
- [x] 4.2 运行后端测试、`web` 构建检查（`npm run build`）及移动端静态检查（`flutter analyze`）确保全部通过
- [x] 4.3 将变更重新部署至 186 环境并验证服务端健康状态与前端静态资源
- [x] 4.4 按需构建移动端 ARMv8 Release APK（`flutter build apk --release --target-platform android-arm64`）并确认产物可用
