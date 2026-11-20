# Spec Delta

## MODIFIED Requirements

### Requirement: Mobile Media Persistent Disk Cache and LRU Eviction
移动端 SHALL 维护按 `user_id` 分桶隔离、并受设备级总配额（默认 200MB，支持用户在设置中自定义）约束的本地磁盘多媒体持久化缓存池，对音视频媒体实施「本地优先播放」、「上传即命中」及「设备级全局 LRU 自动淘汰」策略，彻底解决公网高延迟卡顿并严格保护手机存储空间。

#### Scenario: 本地缓存命中实现零秒开播放
- **WHEN** 用户在 `ItemDetailScreen` 点击播放视频或音频，且该文件在当前用户的缓存分桶（`u_{userId}`）中已存在
- **THEN** 播放器 SHALL 直接加载本地沙箱文件路径（`VideoPlayerController.file` / `DeviceFileSource`），实现 0ms 本地秒开，零外网流量消耗

#### Scenario: 本地未命中时流式下载并异步落盘
- **WHEN** 用户播放未缓存的远程媒体文件
- **THEN** 播放器 SHALL 从外网服务器流式加载（携带有效鉴权凭据），并在后台将媒体完整持久化至当前用户的本地缓存分桶（`u_{userId}`），自动与服务端文件路径建立索引映射，确保二次打开时直接命中本地缓存

#### Scenario: 本机刚上传的音视频就地转存为本地缓存
- **WHEN** 用户在本机 `ItemEditScreen` 录制或拍摄音视频并成功上传服务端
- **THEN** 移动端客户端 SHALL 立即将该本地原文件转存至当前用户的缓存分桶目录并关联服务端返回的 `file_path`，确保该用户在当前设备查看该物品时 100% 命中本地缓存，无需二次通过外网回下

#### Scenario: 切换账号后物理隔离缓存目录且不串读
- **WHEN** 同一台设备从用户 A 切换登录至用户 B
- **THEN** `MediaCacheManager` SHALL 切换至用户 B 的独立缓存子目录（`u_{userId}`）与独立索引键，用户 B 无法命中或读取用户 A 的本地缓存索引

#### Scenario: 缓存超出配额触发 LRU 自动清理至安全水位
- **WHEN** 写入新媒体导致本机所有账号分桶的缓存总容量超过用户设定的设备级配额上限（默认 200MB）
- **THEN** 缓存管理器 SHALL 跨分桶按各缓存文件的最后访问时间（`last_accessed_time`）正序排列，自动剔除最久未访问的媒体文件，直至总容量降至配额的 80% 安全水位线以内

#### Scenario: 通用设置中管理缓存配额与一键清理
- **WHEN** 用户进入「通用设置」的「多媒体存储与缓存」专区
- **THEN** 页面 SHALL 实时展示当前账号已用缓存体积与本机总缓存占比，支持在 100MB、200MB、500MB 与 1GB 之间切换设备级配额上限，并提供「立即清空缓存」操作（弹出危险态 `ShadDialog` 二次确认后默认仅清除当前登录账号的缓存分桶目录并重置其索引）
