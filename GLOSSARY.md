# 图觅 (TraceItem) 领域术语表

“图觅”是一个面向家庭与个人场景的物品视觉收纳、空间定位与多模态寻物系统。

## 空间层级与认知模型 (Spatial & Cognitive Model)

**House (房屋)**:
用户拥有、居住或管理的物理建筑实体（如“阳光城自己家”、“老家自建房”）。在图觅中，房屋属于**用户独立私有作用域 (User-Scoped)**，不同家庭成员拥有各自独立的房屋列表与称谓。
_Avoid_: Home, Apartment, Building

**Room / Space (房间 / 空间)**:
房屋内部由特定用户根据自身生活认知预先配置的功能区域（如“客厅”、“主卧”、“书房”）。在图觅中，橱柜与抽屉无需在数据库中层层配置，完全通过照片与短视频直观传达。
_Avoid_: Zone, Area, Container, Shelf

**God View (上帝视角)**:
仅属于 Admin（管理员）特权账号的全局全景寻物与巡检中枢。Admin 自身不产生日常物品数据，但在紧急情况下可一键跨所有家庭成员执行穿透式检索与位置调阅。
_Avoid_: Super user, Root view

**Space Anchor (空间锚定)**:
用户在批量整理特定房间时，在客户端一键锁定当前空间位置，后续连续录入的物品自动继承该位置属性的高效工作流。若异地补录，用户亦可直接在预设房间胶囊中手动单选归档。
_Avoid_: Location lock, Batch preset

## 核心业务对象 (Core Entities)

**Item (物品)**:
需要留痕、追踪并在日后被寻找的实体物件，拥有名称、品牌规格、数量、所在位置、品类标签与多模态附件。
_Avoid_: Object, Asset, Thing, Good

**Category (分类)**:
物品的行业或功能通用分类划分（如“五金工具”、“数码配件”、“常备药品”、“换季衣物”）。
_Avoid_: Type, Class

**Tag (标签)**:
用于多维度筛选与特征标记的自由文本标签（如“贵重”、“易碎”、“保修期内”、“出差常用”），一件物品可打多个标签。
_Avoid_: Label, Keyword

**Attachment (多模态附件)**:
与物品直接关联的视觉、听觉凭证，包括端侧已压缩的照片 (Image/JPEG)、语音指引备忘 (Audio/AAC) 或空间寻路短视频 (Video/x265)。
_Avoid_: Media, File, Asset

## 媒体管道与工业化存储 (Media & Storage)

**Industrial Media Path (现代工业化存储路径)**:
按实体类型隔离与年月分片的多媒体磁盘组织架构：`/data/media/{type}/{YYYY}/{MM}/{uuid}.{ext}`，彻底杜绝单文件夹内文件堆积与索引衰减。
_Avoid_: Flat upload, Single dir

**FastStart (Moov 移头)**:
在短视频转码封装时，将包含索引与元数据的 `moov` atom 强制挪至 MP4 文件头部（`+faststart`），使公网播放器无需下载完整视频即可实现毫秒级 Progressive 起播。
_Avoid_: Stream preload, Header buffer

**Keyframe Interval (关键帧间隔 / GOP)**:
视频编码时固定的 I 帧间隔（每 1 秒强制插入关键帧），确保公网跨网络拖拽进度条 Seek 时能立即命中关键帧解码，消除卡顿。
_Avoid_: Frame rate, Seek point

## 同步、防丢与备份 (Sync & Backup)

**Sync Queue (离线待同步队列)**:
移动端在地下室、车库等弱网或离线环境下录制物品与附件时，保存在本地的暂存写队列，恢复网络后自动后台静默上传。
_Avoid_: Draft box, Outbox, Cache

**Unsynced Guard (未同步防丢守卫)**:
参考 DinoRoar 的数据防御机制。在 401 令牌过期重登、切换账号或注销时，保护本地未上传的离线数据不被物理抹除，并在高危操作前强制弹窗拦截确认。
_Avoid_: Logout confirmation, Sync lock

**TAR Archive Backup (无损 TAR 打包备份)**:
系统采用无压缩的纯 `.tar` 流将 SQLite 一致性镜像与工业化多媒体目录快速串联打包，零 CPU 算力损耗，支持 Admin 手动一键备份与历史备份记录定期清理。
_Avoid_: Zip compress, Cron backup
