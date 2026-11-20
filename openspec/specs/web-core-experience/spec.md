# web-core-experience Specification

## Purpose
Defines the web frontend item card rendering, client-side visual image compression pipeline, multimodal media attachments management, and item browsing capabilities in TraceItem.

## Requirements

### Requirement: Item Card Media and Thumbnail Rendering
The web application SHALL render item cards with actual thumbnail images and multimodal status badges derived from the attachment `media_type` field and industrial backend storage paths.

#### Scenario: Item with image attachment displays thumbnail
- **WHEN** an item contains attachments where `media_type` is "image"
- **THEN** the item card SHALL display the image via `thumbnail_url` or `/api/media/file/{thumbnail_path}` with squircle rounded borders and hover zoom animation

#### Scenario: Item with audio and video displays multimodal indicators
- **WHEN** an item has attachments where `media_type` is "audio" or "video"
- **THEN** the item card SHALL display distinct Lucide Mic and Video indicator badges at the bottom of the card

### Requirement: Client-Side Image Compression Pipeline
The web application SHALL perform smart proportional client-side downscaling and compression using HTML5 Canvas before uploading images to the backend.

#### Scenario: Large photo compressed before upload
- **WHEN** a user selects a high-resolution photo exceeding 1600px on its longest side
- **THEN** the client SHALL downscale the image proportionally to a maximum dimension of 1600px and encode it as JPEG with 80% to 85% quality before transmitting it via HTTP multipart form-data

### Requirement: Multimodal Attachment Management in Item Dialog
The web application SHALL support uploading, previewing, and managing multiple images, audio voice memos, and spatial guide videos when creating or editing an item.

#### Scenario: Editing an item preserves and allows updating attachments
- **WHEN** a user opens an existing item in the edit dialog
- **THEN** existing attachments SHALL be rendered with preview thumbnails, and the user SHALL be permitted to remove existing attachments or append new photos and media files without data loss

### Requirement: Kid-Friendly Typography Standard Compliance
All web typography across item cards, dialogs, forms, and preview modals SHALL adhere to readable font sizes without any sub-12px elements.

#### Scenario: Strict absence of sub-12px typography
- **WHEN** any web component is rendered
- **THEN** no element SHALL have font size classes of `text-[10px]` or `text-[11px]`, and body descriptions and form labels SHALL use at least 14px (`text-sm`)

### Requirement: Interactive Web Photo Zoom and Pan Viewer
The web application SHALL provide an interactive image viewer supporting mouse-wheel zoom, drag-to-pan, and 1:1 pixel reset controls in the media preview dialog.

#### Scenario: User zooms in with mouse wheel
- **WHEN** a user hovers over the previewed photo and rotates the mouse scroll wheel
- **THEN** the image SHALL smoothly scale between 100% and 400% anchored at the mouse cursor position, with a floating control capsule providing zoom level indicator and one-click reset.

### Requirement: Custom Dopamine Audio and Video Player Components
The web application SHALL replace native `<audio>` and `<video>` tags with custom styled dopamine UI components featuring rounded squircle borders, progress scrubbing, and playback rate toggles.

#### Scenario: User plays audio with custom controls
- **WHEN** a user clicks the play button on an audio voice memo in the preview modal
- **THEN** the custom dopamine player SHALL play the AAC stream, render dynamic waveform indicator and scrubbable progress bar, and support switching between 1.0x and 1.5x speed without using browser native audio bars.

#### Scenario: User plays video guide without native browser controls
- **WHEN** a user previews a spatial video guide
- **THEN** the video container SHALL render with 20px squircle rounded borders, centered play overlay, custom seekbar, and zero unstyled native control bars.

### Requirement: Virtual Sliding Window Grid for Large-Scale Items
The web application SHALL implement a virtual sliding window grid for item browsing that mounts only the cards within the visible viewport plus top and bottom buffer lines.

#### Scenario: Maintaining bounded DOM nodes during vertical scroll
- **WHEN** a user navigates or scrolls vertically through hundreds or thousands of items
- **THEN** the total mounted item card DOM elements in the grid container SHALL remain bounded under 40 elements at all times, with dynamic top and bottom spacer paddings maintaining the natural scrollbar height and position.

### Requirement: Web 端物品清单触底增量分页与服务端分类过滤
Web 端物品清单 SHALL 取消单次写死 500 条的拉取上限，改为配合 `VirtualItemGrid` 虚拟滑动窗口的后端分页增量加载，并将分类筛选参数下沉至服务端 `/items` 接口查询，确保上千件物品均可完整浏览与精确筛选。

#### Scenario: 超过 500 件物品的触底自动翻页
- **WHEN** 用户当前空间存在超过 500 件物品，并在页面滚动接近虚拟网格底部时
- **THEN** Web 端 SHALL 自动请求下一页数据（如每页 60 条）并平滑追加至当前列表，同时在底部展示加载状态或「已全部加载」提示，不截断第 501 件及之后的物品

#### Scenario: 分类筛选与空间切换触发服务端分页重置
- **WHEN** 用户在 Web 端切换房屋、房间或选择特定分类过滤胶囊时
- **THEN** Web 端 SHALL 重置页码至第 1 页并将 `house_id`、`room_id`、`category_id` 一并传给服务端 `/items` 接口重新分页拉取，避免仅在前端过滤局部缓存导致漏掉后续页物品

#### Scenario: 翻页失败恢复与统一提示
- **WHEN** Web 端增量翻页请求因网络异常失败时
- **THEN** Web 端 SHALL 通过底部重试控件与统一 `toastStore` 轻提示通知用户并保留已加载数据，严禁调用浏览器原生 `alert()` 或 `confirm()`
