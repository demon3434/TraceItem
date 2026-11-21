# Spec Delta

## ADDED Requirements

### Requirement: Empty Remote Item Response Cache Invalidation
当移动端物品寻宝首页拉取远端物品列表返回为空（且当前为第 1 页、无搜索关键字过滤）时，移动端 SHALL 显式清理本地 SQLite 离线数据库（`cached_items`）中对应筛选维度的缓存记录，严禁保留已被清空或不存在的残留脏数据。

#### Scenario: 云端空间为空时自动清理本地残留缓存
- **WHEN** 移动端拉取当前房屋或默认空间的第 1 页物品，服务端明确返回空列表（total 为 0）
- **THEN** 移动端清除本地数据库中当前用户对应房屋/范围的 `cached_items` 记录，界面展示空状态而非历史残留物品

